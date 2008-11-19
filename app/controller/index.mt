?=r render_partial('header.mt')
<script type="text/javascript" src="<?= docroot ?>static/jquery.js"></script>
<script type="text/javascript"><!--
$(function() {
    setTimeout(function() {
        $('.animatedTitle').slideDown(2000);
    }, 1000);
});
//--></script>

<p align="right"><?= localtime time ?></p>

<div class="animatedTitle" style="display: none; padding: 1em;">
<h2 style="text-decoration: underline;">Web Application Framework - MENTA</h2>
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
<ul><a href="<?= uri_for('tutorial') ?>">取り扱い説明書</a></ul>
<ul><a href="<?= uri_for('modules') ?>">添付モジュールについて</a></ul>
</ul>

<h2 class="subtitle">デモ</h2>
<ul>
    <li><a href="<?= uri_for('form') ?>">フォーム</a></li>
    <li><a href="<?= uri_for('goto_wassr') ?>">リダイレクト(Wassr にとびます)</a></li>
    <li><a href="<?= uri_for('users') ?>">DBI(DBI および DBD::CSV がないとエラーになります)</a></li>
    <li><a href="<?= uri_for('die') ?>">エラー画面</a></li>
    <li><a href="<?= uri_for('mobile') ?>">モバイル</a></li>
    <li><a href="<?= uri_for('bbs_sqlite') ?>">SQLite をつかった掲示板(DBD::SQLite が必要です)</a></li>
    <li><a href="<?= uri_for('counter') ?>">簡単なカウンター</a></li>
    <li><a href="<?= uri_for('hello', { user => 'kazuhooku' }) ?>">PHP っぽくそのままテンプレート表示しちゃう</a></li>
    <li><a href="<?= uri_for('perlinfo') ?>">perlinfo()</a></li>
</ul>

<h2 class="subtitle">LICENSE</h2>
<p>MENTA は Perl License のもとで配布されます。具体的にいうと、なんでも好きなようにしてよい、ということです。</p>

<h2 class="subtitle">開発者</h2>
<ol><?=r join "\n", map { '<li>' . escape_html($_) . '</li>' } split /\n/, read_file('AUTHORS') ?></ol>

?=r render_partial('footer.mt')
