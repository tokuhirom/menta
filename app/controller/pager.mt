? my $pager = shift;
? my $action = shift;
? my $page_n = $pager->{page};
? if ($pager->{page} == 1) {
前
? } else {
<a href="<?= uri_for($action, { page => $page_n - 1 }) ?>" rel="prev">前</a>
? }
|
? if ($pager->{has_next}) {
<a href="<?= uri_for($action, { page => $page_n + 1 }) ?>" rel="next">次</a>
? } else {
次
? }
(現在: <?= $page_n ?>)
