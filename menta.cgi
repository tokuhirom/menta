#!/usr/bin/perl
use lib 'lib', 'vendor/lib';
use MENTA;
# -- ここまではおまじない --

run_menta({
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        kcatch_mode => 1,
        # 最大表示文字数
        max_post_body => 1_024_000,
    },
    # あなたのアプリの設定
    application => {
        docroot => '',
        title => 'MENTA サンプルアプリ',
        sqlitefile => 'app/data/data.sqlite',
        sql => {
            dsn => 'dbi:SQLite:app/data/data.sqlite',
        },
        counter => {
            file => 'app/data/counter.txt'
        },
    },
});

# 以下、あなたのプログラム

