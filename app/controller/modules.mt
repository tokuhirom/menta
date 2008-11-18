? my $title = "MENTA標準添付モジュールについて"
?=r render_partial('header.mt', $title)

<pre><?= read_file('MODULES') ?></pre>

?=r render_partial('footer.mt', $title)
