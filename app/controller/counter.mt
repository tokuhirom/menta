? my $title = 'カウンターのデモ'
? load_plugin('counter')
?=r render_partial('header.mt', $title)
<h1><?= $title ?></h1>
現在の訪問者数は: <?= counter_increment('test') ?>人です。
?=r render_partial('footer.mt')
