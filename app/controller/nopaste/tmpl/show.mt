? my $row = shift;

? extends 'base.mt';
? block content => sub {

<h1>nopaste </h1>
<form method="get"><input type="text" size="100" value="<?= current_url() ?>" /></form>
<pre><?= $row->{body} ?></pre>

? }
