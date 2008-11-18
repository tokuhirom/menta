? my ($entries, $pager) = @_
? my $title = 'SQLite をつかった一行掲示板'
?=r render_partial('header.mt', 'SQLite をつかった一行掲示板')
<form method="post" action="<?= uri_for('bbs_sqlite') ?>">
 <input type="text" name="body">
 <input type="submit" value="送信">
</form>

<ul>
? for my $entry (@{$entries}) {
 <li class="hentry"><?= $entry->{id} ?> <?= $entry->{body} ?></li>
? }
</ul>
?=r render_partial('pager.mt', $pager, 'bbs_sqlite')
?=r render_partial('footer.mt')
