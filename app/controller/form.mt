?= render_partial('header.mt', 'フォームを使った例')
<div class="blocked-content">
? my $r = param('r') || ''
<p>パラメータ r: "<?= $r ?>"</p>

<h2 class="subtitle">GET</h2>
<form method="get" action="<?= uri_for('form') ?>"><input type="text" name="r"><input type="submit" value="送信"></form>

<h2 class="subtitle">POST</h2>
<form method="post" action="<?= uri_for('form') ?>"><input type="text" name="r"><input type="submit" value="送信"></form>
</div>
?= render_partial('footer.mt')
