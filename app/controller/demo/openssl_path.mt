? extends 'base.mt';

? block title => 'openssl path - MENTA';

? block content => sub {

<p>あなたの OpenSSL は <code>
<?= `which openssl` ?>
</code></p>


? }
