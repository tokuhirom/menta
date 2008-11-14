use DBI;

# DBI ってやっぱりわかりにくいよねえ。もうちょいすっきりこれを書けるプラグインが欲しい。

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
        my $page = param('page') || 1;
        my $limit = 10; # 1ページあたりの表示件数
        my $offset = ($page-1) * $limit;
        my $sth = $dbh->prepare('SELECT id, body FROM entries ORDER BY id DESC LIMIT ? OFFSET ?') or die $dbh->errstr;
        $sth->execute($limit+1, $offset);
        my @res;
        while (my ($id, $body) = $sth->fetchrow_array()) {
            push @res, {id => $id, body => $body};
        }
        my $has_next = 0;
        if (@res == $limit+1) {
            pop @res;
            $has_next++;
        }
        render("bbs.html", \@res, { page => $page, has_next => $has_next});
    }
}

