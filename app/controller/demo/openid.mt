?= render('header.mt')

<h2>OpenID でログインするデモ</h2>
? if (my $user = openid_get_user()) {
    <p><?= $user->{nickname} ?> さん こんにちは！</p>

    <form method="post" action="<?= session_logout_url(uri_for('demo/openid')) ?>">
        <p><input type="submit" value="ログアウト"></p>
    </form>
? } else {
    <ul>
?   my $map = openid_login_url_map( cancelled => uri_for('demo/openid_cancelled'), verified => uri_for('demo/openid') );
?   while (my ($name, $url) = each %$map) {
        <li><a href="<?= $url ?>"><?= $name ?> でログイン</a></li>
?   }
    </ul>
? }

?= render('footer.mt')
