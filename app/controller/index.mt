?= render('header.mt')
<script type="text/javascript" src="<?= static_file_path('jquery.js') ?>"></script>

<p align="right"><?= localtime time ?></p>

<div class="animatedTitle" style="padding: 1em;">
<h2 style="text-decoration: underline;">Web Application Framework - MENTA <?= $MENTA::VERSION ?></h2>
<div class="blocked-content"><p>MENTA is lightweight Web application framework</p></div>
</div>

<p>このページが見えていれば、MENTA のインストールに成功しています</p>

<h2 class="subtitle">MENTA ってなに?</h2>
<p>MENTA は CGI で気軽につかえる Web アプリケーションフレームワークです</p>
<ul>
    <li>CGI でも高速に動作</li>
    <li>レンタルサーバーでもつかえます(ロリポとか XREA とか)</li>
    <li>Object 指向がわからなくてもつかえます</li>
    <li>正しいプログラミングスタイルが自然と身につきます</li>
</ul>

<h2 class="subtitle">現在利用できる項目</h2>
<ul>
    <li><a href="<?= uri_for('manual/index') ?>">マニュアル</a></li>
    <li><a href="<?= uri_for('demo/index')   ?>">MENTA デモ</a></li>
    <li><a href="<?= uri_for('nopaste/')   ?>">NoPaste デモ</a></li>
</ul>

?= render('footer.mt')
