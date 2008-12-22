package MENTA::Plugin::SQL;
use MENTA::Plugin;
use DBI;

sub sql_dbh {
    if (@_) {
        my @args = @_;
        if ($MENTA::STASH->{sql_dbh}) {
            $MENTA::STASH->{sql_dbh}->disconnect;
            undef $MENTA::STASH->{sql_dbh};
        }
        my $dbh = DBI->connect(@args) or die "DBに接続できません: $DBI::errstr";
        $dbh->{unicode} = 1;
        $MENTA::STASH->{sql_dbh} = $dbh;
        $dbh;
    } else {
        $MENTA::STASH->{sql_dbh} ||= do {
            my $dsn = config->{application}->{sql}->{dsn} or die "設定に application.sql.dsn がありません";
            my $dbh = DBI->connect($dsn) or die "DBに接続できません: $DBI::errstr";
            $dbh->{unicode} = 1;
            $dbh;
        };
    }
}

sub sql_do {
    my ($sql, @params) = @_;
    my $dbh = sql_dbh();
    $dbh->do($sql) or die "prepare できません: " . $dbh->errstr();
}

sub sql_prepare_exec {
    my ($sql, @params) = @_;
    my $dbh = sql_dbh();
    my $sth = $dbh->prepare($sql) or die "prepare できません: " . $dbh->errstr();
    $sth->execute(@params) or die "exec できません: " . $dbh->errstr;
    $sth->finish();
    undef $sth;
}

sub sql_select_all {
    my ($sql, @params) = @_;

    my $dbh = sql_dbh();
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute(@params) or die $dbh->errstr;
    my @res;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }
    $sth->finish;
    undef $sth;

    return \@res;
}

sub sql_select_paginate {
    my ($sql, $params, $paging) = @_;
    $sql .= ' LIMIT ? OFFSET ?';

    my $dbh = sql_dbh();
    my $sth = $dbh->prepare($sql) or die $dbh->errstr;
    $sth->execute(@$params, $paging->{rows}+1, ($paging->{page}-1)*$paging->{rows});

    my @res;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }
    $sth->finish;
    undef $sth;

    my $has_next = 0;
    if ( @res == $paging->{rows} + 1 ) {
        pop @res;
        $has_next++;
    }

    return (\@res, {page => $paging->{page}, has_next => $has_next, has_prev => ($paging->{page} == 1) ? 1 : 0});
}

1;
# AUTHOR: tokuhirom, mattn
