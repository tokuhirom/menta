?= render('header.mt', 'フォームを使った例2')
<div class="blocked-content">
? my @params = param('r')
<p>パラメータ</p>
? for my $r (@params) {
      r:"<?= $r ?>"<br />
? }

<form method="get" action="<?= uri_for('demo/form2') ?>"><fieldset><legend>GET</legend><input type="checkbox" name="r" value="foo">foo<br /><input type="checkbox" name="r" value="bar">bar<br /><input type="submit" value="送信"></fieldset></form>

<form method="post" action="<?= uri_for('demo/form2') ?>"><fieldset><legend>POST</legend><input type="checkbox" name="r" value="foo">foo<br /><input type="checkbox" name="r" value="bar">bar<br /><input type="submit" value="送信"></fieldset></form>
</div>
?= render('footer.mt')
