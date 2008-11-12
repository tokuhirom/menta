#!/usr/bin/perl
use lib 'lib';
use MENTA::Base;
# -- ここまではおまじない --

# 設定
config({
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        kcatch_mode => 1,
        # 最大表示文字数
        max_post_body => 1000000,
        # テンプレートファイルディレクトリへのパス
        tmpl_dir => 'out/tmpl',
    },
    # あなたのアプリの設定
    application => {
        title => "MENTA サンプルアプリ",
    },
});

# あなたのプログラム
sub do_index {
    my $REQ = shift;
    render('index.html', config()->{application}->{title});
}

sub do_goto_wassr {
    redirect('http://wassr.jp/');
}

# おまじない
MENTA->run;

