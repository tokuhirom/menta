require "../plugins/dbi_select.pl";

sub do_users {
    my @rows = dbi_select('DBI:CSV:f_dir=../app/data', 'select * from users');
    render('users.html', \@rows);
}

