? my ($entries, $pager) = @_
?= render('header.mt', 'SQLite をつかった一行掲示板')
<div class="blocked-content">
<form method="post" action="<?= uri_for('bbs_sqlite') ?>">
 <input type="text" name="body">
 <input type="submit" value="送信">
</form>

<ul>
? for my $entry (@{$entries}) {
 <li class="hentry"><?= $entry->{id} ?> <?= $entry->{body} ?></li>
? }
</ul>
?= render('pager.mt', $pager, 'bbs_sqlite')
</div>
?= render('footer.mt')
