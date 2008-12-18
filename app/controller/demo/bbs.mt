? my ($entries, $pager) = @_;
?= render('header.mt', 'SQLite をつかった一行掲示板')
<div class="blocked-content">

? if (my $user = openid_get_user()) {
    <p><?= $user->{nickname} ?> さんこんにちは</p>

    <form method="post" action="<?= uri_for('demo/bbs_sqlite') ?>">
    <p><input type="text" name="body">
    <input type="submit" value="送信"></p>
    </form>

    <form method="post" action="<?= session_logout_url(uri_for('demo/openid')) ?>">
        <p><input type="submit" value="ログアウト"></p>
    </form>
? } else {
    <p>発言するにはログインが必要です (個人情報は記録／公開されます)</p>
    <ul>
?   my $map = openid_login_url_map( cancelled => uri_for('demo/bbs_sqlite'), verified => uri_for('demo/bbs_sqlite') );
?   while (my ($name, $url) = each %$map) {
        <li><a href="<?= $url ?>"><?= $name ?> でログイン</a></li>
?   }
    </ul>
? }

<ul>
? for my $entry (@{$entries}) {
    <li class="hentry"><?= $entry->{id} ?> <?= $entry->{body} ?> by <a href="<?= $entry->{openid} ?>"><?= $entry->{nickname} ?></a></li>
? }
</ul>
?= render('pager.mt', $pager, 'demo/bbs_sqlite')
</div>
?= render('footer.mt')
