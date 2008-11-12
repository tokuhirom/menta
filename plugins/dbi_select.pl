use utf8;
use Symbol ();
use DBI;

sub dbi_select {
    my ($dbname, $sql) = @_;

    my $dbh = DBI->connect($dbname) or die "Cannot connect: " . $DBI::errstr;
    my $sth = $dbh->prepare($sql) or die "Cannot prepare: " . $dbh->errstr();
    $sth->execute() or die "Cannot execute: " . $sth->errstr();
    my @res;
    while (my $row = $sth->fetchrow_hashref) {
        push @res, $row;
    }
    $sth->finish();
    $dbh->disconnect();
    @res;
}

1;
