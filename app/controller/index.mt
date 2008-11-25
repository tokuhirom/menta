?= render('header.mt')
<script type="text/javascript" src="<?= static_file_path('jquery.js') ?>"></script>

<p align="right"><?= localtime time ?></p>

<div class="animatedTitle" style="padding: 1em;">
<h2 style="text-decoration: underline;">Web Application Framework - MENTA <?= $MENTA::VERSION ?></h2>
<div class="blocked-content"><p>MENTA is lightweight web application framework</p></div>
</div>

<h2 class="subtitle">MENTA ってなに?</h2>
<p>MENTA は CGI で気軽につかえるウェブアプリケーションフレームワークです</p>
<ul>
    <li>CGI でも高速に動作</li>
    <li>レンタルサーバーでもつかえます(ロリポとかXREAとか)</li>
    <li>Object 指向がわからなくてもつかえます</li>
    <li>正しいプログラミングスタイルが自然と身につきます</li>
</ul>

<h2 class="subtitle">マニュアル</h2>
<ul>
<ul><a href="<?= uri_for('tutorial') ?>">チュートリアル</a></ul>
<ul><a href="<?= uri_for('install') ?>">インストール方法</a></ul>
<ul><a href="<?= uri_for('modules') ?>">添付モジュールについて</a></ul>
</ul>

<h2 class="subtitle">デモ</h2>
<ul>
    <li><a href="<?= uri_for('form') ?>">フォーム</a></li>
    <li><a href="<?= uri_for('goto_wassr') ?>">リダイレクト(Wassr にとびます)</a></li>
    <li><a href="<?= uri_for('die') ?>">エラー画面</a></li>
    <li><a href="<?= uri_for('mobile') ?>">モバイル</a></li>
    <li><a href="<?= uri_for('bbs_sqlite') ?>">SQLite をつかった掲示板(DBD::SQLite が必要です)</a></li>
    <li><a href="<?= uri_for('counter') ?>">簡単なカウンター</a></li>
    <li><a href="<?= uri_for('hello', { user => 'kazuhooku' }) ?>">PHP っぽくそのままテンプレート表示しちゃう</a></li>
    <li><a href="<?= uri_for('perlinfo') ?>">perlinfo()</a></li>
    <li><a href="<?= uri_for('session') ?>">session管理</a></li>
</ul>

<h2 class="subtitle">LICENSE</h2>
<p>MENTA は Perl License のもとで配布されます。具体的にいうと、なんでも好きなようにしてよい、ということです。</p>

<h2 class="subtitle">開発者</h2>
<ol><?=r join "\n", map { '<li>' . escape_html($_) . '</li>' } split /\n/, file_read('AUTHORS') ?></ol>

?= render('footer.mt')
