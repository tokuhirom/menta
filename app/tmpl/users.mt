?=r render_partial('header.mt', 'DBI')
<div class="blocked-content">
<table>
 <caption>ユーザ</caption>
 <thead>
  <tr><th>ID</th><th>名前</th></tr>
 </thead>
 <tbody>
? for my $c (@{$_[0]}) {
  <tr><td><?= $c->{id} ?></td><td><?= $c->{name} ?></td></tr>
? }
 <tbody>
</table>
</div>
?=r render_partial('footer.mt')
