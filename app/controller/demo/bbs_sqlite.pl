use MENTA::Controller;

sub run {
    sql_prepare_exec(q{CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY, nickname VARCHAR(255), openid TEXT, body VARCHAR(255))});

    if (is_post_request()) {
        my $user = openid_get_user();
        my $body = param('body');
        if ($body && $user) {
            sql_prepare_exec('INSERT INTO entries (body, nickname, openid) VALUES (?, ?, ?)', $body, $user->{nickname}, $user->{openid});
        }
        redirect(uri_for('demo/bbs_sqlite'));
    } else {
        my ( $rows, $pager ) = sql_select_paginate(
            'SELECT id, body, nickname, openid FROM entries ORDER BY id DESC',
            [],
            {
                page => param('page') || 1,
                rows => 10,
            }
        );
        render_and_print('demo/bbs.mt', $rows||[], $pager);
    }
}

