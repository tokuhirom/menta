use DBI;

# DBI ってやっぱりわかりにくいよねえ

sub do_bbs_sqlite {
    my $dbh = DBI->connect('dbi:SQLite:dbname=' . config->{application}->{sqlitefile}, '', '') or die $DBI::errstr;
    $dbh->{unicode}++;
    $dbh->do(q{CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY, body VARCHAR(255))}) or die $dbh->errstr;
    if (is_post_request) {
        my $body = param('body');
        if ($body) {
            my $sth = $dbh->prepare('INSERT INTO entries (body) VALUES (?)') or die $dbh->errstr;
            $sth->execute($body) or die $dbh->errstr;
        }
        redirect(docroot . 'bbs_sqlite');
    } else {
        my $sth = $dbh->prepare('SELECT id, body FROM entries ORDER BY id DESC LIMIT 10') or die $dbh->errstr;
        $sth->execute();
        my @res;
        while (my ($id, $body) = $sth->fetchrow_array()) {
            push @res, {id => $id, body => $body};
        }
        render("bbs.html", \@res);
    }
}

