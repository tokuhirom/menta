?= render('header.mt')

<h1 class="subtitle">MENTA デモサイト</h1>
<p>MENTA をつかったデモアプリケーションを展示しています。</p>
<ul>
    <li><a href="<?= uri_for('demo/form')         ?>">フォーム</a></li>
    <li><a href="<?= uri_for('demo/goto_wassr')   ?>">リダイレクト(Wassr にとびます)</a></li>
    <li><a href="<?= uri_for('demo/die')          ?>">エラー画面</a></li>
    <li><a href="<?= uri_for('demo/mobile')       ?>">モバイル</a></li>
    <li><a href="<?= uri_for('demo/bbs_sqlite')   ?>">SQLite をつかった掲示板(DBD::SQLite が必要です)</a></li>
    <li><a href="<?= uri_for('demo/counter')      ?>">簡単なカウンター</a></li>
    <li><a href="<?= uri_for('demo/hello', { user => 'kazuhooku' }) ?>">PHP っぽくそのままテンプレート表示しちゃう</a></li>
    <li><a href="<?= uri_for('demo/perlinfo')     ?>">perlinfo()</a></li>
    <li><a href="<?= uri_for('demo/session')      ?>">session管理</a></li>
    <li><a href="<?= uri_for('demo/openid')       ?>">OpenID(LWP, Crypt::SSLeay|Net::SSL が必要)</a></li>
    <li><a href="<?= uri_for('demo/openssl_path') ?>">OpenSSL のパスを表示します(*nix系OSでのみ動作)</a></li>
</ul>

?= render('footer.mt')
