load_plugin('sql');

# DBI ってやっぱりわかりにくいよねえ。もうちょいすっきりこれを書けるプラグインが欲しい。

sub do_bbs_sqlite {
    sql_prepare_exec(q{CREATE TABLE IF NOT EXISTS entries (id INTEGER PRIMARY KEY, body VARCHAR(255))});

    if (is_post_request) {
        my $body = param('body');
        if ($body) {
            sql_prepare_exec('INSERT INTO entries (body) VALUES (?)', $body);
        }
        redirect(docroot . 'bbs_sqlite'); # TODO: use uri_for
    } else {
        my ( $rows, $pager ) = sql_select_paginate(
            'SELECT id, body FROM entries ORDER BY id DESC',
            [],
            {
                page => param('page') || 1,
                rows => 10,
            }
        );
        render("bbs.html", $rows, $pager);
    }
}

