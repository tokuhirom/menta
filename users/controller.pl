# =========================================================================
# 設定
#
# =========================================================================

$MENTA::CONFIG = {
    # MENTA 自体の設定
    menta => {
        # Perl のパス
        perlpath => '/usr/bin/perl',
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
};

sub do_index {
    my $REQ = shift;
    render('index.html');
}

sub do_goto_wassr {
    redirect('http://wassr.jp/');
}
