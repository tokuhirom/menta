? my $title = config()->{application}->{title}
?=r render_partial('header.mt')
<script type="text/javascript" src="<?= docroot ?>static/jquery.js"></script>
<script type="text/javascript"><!--
$(function() {
    var $this = $('h1');
    $this.css({background : 'orange'})
         .text($this.text().replace('MENTA', 'めんた'));
});
//--></script>

<h1><?= $title ?></h1>
<p><?= localtime time ?></p>

<h2>MENTA ってなに?</h2>
<p>MENTA は CGI で気軽につかえるウェブアプリケーションフレームワークです</p>
<ul>
    <li>CGI でも高速に動作</li>
    <li>レンタルサーバーでもつかえます(ロリポとかXREAとか)</li>
    <li>Object 指向がわからなくてもつかえます</li>
    <li>正しいプログラミングスタイルが自然と身につきます</li>
</ul>

<p><a href="<?= uri_for('tutorial') ?>">取り扱い説明書</a></p>

<h2>デモ</h2>
<ul>
    <li><a href="<?= uri_for('form') ?>">フォーム</a></li>
    <li><a href="<?= uri_for('goto_wassr') ?>">リダイレクト(Wassr にとびます)</a></li>
    <li><a href="<?= uri_for('users') ?>">DBI(DBI および DBD::CSV がないとエラーになります)</a></li>
    <li><a href="<?= uri_for('die') ?>">エラー画面</a></li>
    <li><a href="<?= uri_for('mobile') ?>">モバイル</a></li>
    <li><a href="<?= uri_for('bbs_sqlite') ?>">SQLite をつかった掲示板(DBD::SQLite が必要です)</a></li>
    <li><a href="<?= uri_for('counter') ?>">簡単なカウンター</a></li>
    <li><a href="<?= uri_for('hello', { user => 'kazuhooku' }) ?>">PHP っぽくそのままテンプレート表示しちゃう</a></li>
</ul>

<h2>LICENSE</h2>
<p>MENTA は Perl License のもとで配布されます。具体的にいうと、なんでも好きなようにしてよい、ということです。</p>

?=r render_partial('footer.mt')
