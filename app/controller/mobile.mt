?= render('header.mt', 'ケータイ対応')
<div class="blocked-content">
<p>あなたのブラウザは <?= mobile_agent()->carrier_longname ?> です</p>
</div>
?= render('footer.mt')
