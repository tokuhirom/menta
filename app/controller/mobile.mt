?=r render_partial('header.mt', 'ケータイ対応')
<div class="blocked-content">
<p>あなたのブラウザは <?= mobile_agent()->carrier_longname ?> です</p>
</div>
?=r render_partial('footer.mt')
