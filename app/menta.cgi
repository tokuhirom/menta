#!/usr/bin/perl
use lib '../lib';
use MENTA;
# -- ここまではおまじない --

require "../plugins/mail.pl";
require "plugins/dbi_select.pl";

run_menta({
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        kcatch_mode => 1,
        # 最大表示文字数
        max_post_body => 1000000,
        # テンプレートファイルディレクトリへのパス
        tmpl_dir => 'tmpl/',
        # テンプレートファイルのキャッシュディレクトリへのパス
        tmpl_cache_dir => 'tmpl_cache/',
    },
    # あなたのアプリの設定
    application => {
        docroot => '',
        title => 'MENTA サンプルアプリ',
    },
});

# あなたのプログラム
sub do_index {
    my $REQ = shift;
    render('index.html');
}

sub do_goto_wassr {
    redirect('http://wassr.jp/');
}

sub do_mail {
    mail_send('info@example.com', 'this is subject', 'hi!');
    redirect('http://example.com');
}

sub do_users {
    my $REQ = shift;
    my @rows = dbi_select('DBI:CSV:f_dir=../app/data', 'select * from users');
    render('users.html', \@rows);
}

