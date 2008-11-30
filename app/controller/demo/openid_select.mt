? my $OP_MAP = shift
?= render('header.mt')

<h2>OpenID でログインするデモ</h2>
<ul>
? for my $op (keys %$OP_MAP) {
    <li><a href="<?= uri_for('demo/openid', {op => $op, check => 1}) ?>"><?= $op ?> でログイン</a></li>
? }
</ul>

?= render('footer.mt')
