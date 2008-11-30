use MENTA::Controller;

sub do_bbs_sqlite {
    sql_prepare_exec(q{CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY, body VARCHAR(255))});

    if (is_post_request) {
        my $body = param('body');
        if ($body) {
            sql_prepare_exec('INSERT INTO entries (body) VALUES (?)', $body);
        }
        redirect(uri_for('demo/bbs_sqlite'));
    } else {
        my ( $rows, $pager ) = sql_select_paginate(
            'SELECT id, body FROM entries ORDER BY id DESC',
            [],
            {
                page => param('page') || 1,
                rows => 10,
            }
        );
        render_and_print('demo/bbs.mt', $rows, $pager);
    }
}

