{
    # MENTA 自体の設定
    menta => {
        # エラー出力するか？
        fatals_to_browser  => 1,
        # 最大表示文字数
        max_post_body => 1_024_000,
        # モバイル対応
        support_mobile => 1,
        # MENTA そのものをおいているディレクトリ。CGI の場合は設定しなくてもよい。末尾のスラッシュを忘れずに。
        base_dir => '/var/www/menta/',
    },
    # あなたのアプリの設定
    application => {
        title => 'MENTA サンプルアプリ',
        sqlitefile => '/var/www/menta/app/data/data.sqlite',
        sql => {
            dsn => 'dbi:SQLite:/var/www/menta/app/data/data.sqlite',
        },
        counter => {
            file => '/var/www/menta/app/data/counter.txt'
        },
    },
}
