use MENTA;

load_plugin("sql");

sub do_users {
    sql_dbh('DBI:CSV:f_dir='.data_dir);
    my $rows = sql_select_all('select * from users');
    render('users.mt', $rows);
}

