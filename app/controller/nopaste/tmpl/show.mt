? my $row = shift
?= render('header.mt')

<h1>nopaste </h1>
<form method="get"><input type="text" size="100" value="<?= current_url() ?>" /></form>
<pre><?= $row->{body} ?></pre>

?= render('footer.mt')
