? my $vident = shift;
?= render('header.mt')

<p>OpenID での認証に成功しました</p>

<table>
? while (my ($key, $val) = each %$vident) {
    <tr><th><?= $key ?></th><td><?= $val ?></td></tr>
? }
</table>

?= render('footer.mt')
