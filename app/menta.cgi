#!/usr/bin/perl
use lib '../lib';
use MENTA;
# -- ここまではおまじない --

run_menta({
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        kcatch_mode => 1,
        # 最大表示文字数
        max_post_body => 1_024_000,
        # コントローラーをいれるディレクトリ
        controller_dir => 'controller/',
        # テンプレートファイルディレクトリへのパス
        tmpl_dir => 'tmpl/',
        # テンプレートファイルのキャッシュディレクトリへのパス
        tmpl_cache_dir => 'tmpl_cache/',
    },
    # あなたのアプリの設定
    application => {
        docroot => '',
        title => 'MENTA サンプルアプリ',
        sqlitefile => 'data/data.sqlite',
        counterfile => 'data/counter.txt',
        sql => {
            dsn => 'dbi:SQLite:data/data.sqlite',
        },
    },
});

# あなたのプログラム
sub do_index {
    render('index.html');
    die "DON'T REACH HERE";
}

sub do_goto_wassr {
    redirect('http://wassr.jp/');
}

sub do_form {
    my $r = param('r') || '';
    render('form.html', $r);
}

sub do_die {
    die "こういう風に死にます"
}

sub do_mobile {
    render('mobile.html');
}

