?= render('header.mt')
<script type="text/javascript" src="<?= static_file_path('jquery.js') ?>"></script>

<p align="right"><?= localtime time ?></p>

<h2 class="subtitle">MENTA マニュアル <?= $MENTA::VERSION ?></h2>
<ul>
<ul><a href="<?= uri_for('manual/tutorial') ?>">チュートリアル</a></ul>
<ul><a href="<?= uri_for('manual/install') ?>">インストール方法</a></ul>
<ul><a href="<?= uri_for('manual/modules') ?>">添付モジュールについて</a></ul>
</ul>

<h2 class="subtitle">LICENSE</h2>
<p>MENTA は Perl License のもとで配布されます。具体的にいうと、なんでも好きなようにしてよい、ということです。</p>

<h2 class="subtitle">開発者</h2>
<ol><?=r join "\n", map { '<li>' . escape_html($_) . '</li>' } split /\n/, file_read('AUTHORS') ?></ol>

?= render('footer.mt')
