?= render('header.mt', 'フォームを使った例')
<div class="blocked-content">
? my $r = param('r') || ''
<p>パラメータ r: "<?= $r ?>"</p>

<form method="get" action="<?= uri_for('demo/form') ?>"><fieldset><legend>GET</legend><input type="text" name="r"><input type="submit" value="送信"></fieldset></form>

<form method="post" action="<?= uri_for('demo/form') ?>"><fieldset><legend>POST</legend><input type="text" name="r"><input type="submit" value="送信"></fieldset></form>
</div>
?= render('footer.mt')
