#!/usr/bin/perl
BEGIN {
    unshift @INC, 'lib', 'extlib';
};
use MENTA;
use HTTP::Engine::MinimalCGI;
# -- ここまではおまじない --

MENTA->run_menta({
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        fatals_to_browser  => 1,
        # 最大表示文字数
        max_post_body => 1_024_000,
        # モバイル対応
        support_mobile => 1,
    },
    # あなたのアプリの設定
    application => {
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

