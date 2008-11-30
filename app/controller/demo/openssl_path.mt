?= render('header.mt')

<p>あなたの OpenSSL は</p>

<?= `which openssl` ?>

?= render('footer.mt')
