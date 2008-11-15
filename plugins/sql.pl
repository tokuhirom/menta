# AUTHOR: tokuhirom

use strict;
use warnings;
use utf8;
use DBI;

sub sql_dbh {
    $MENTA::STASH->{sql_dbh} ||= do {
        my $dsn = config->{application}->{sql}->{dsn} or die "設定に application.sql.dsn がありません";
        my $dbh = DBI->connect($dsn) or die "DBに接続できません: $DBI::errstr";
        $dbh->{unicode}++;
        $dbh;
    };
}

sub sql_prepare_exec {
    my ($sql, @params) = @_;
    my $dbh = sql_dbh();
    my $sth = $dbh->prepare($sql) or die "prepare できません: " . $dbh->errstr();
    $sth->execute(@params) or die "exec できません: " . $dbh->errstr;
    $sth->finish();
    undef $sth;
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
