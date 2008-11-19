?=r render_partial('header.mt', 'ケータイ対応')
? use HTTP::MobileAgent
<div class="blocked-content">
<p>あなたのブラウザは <?= HTTP::MobileAgent->new->carrier_longname ?> です</p>
</div>
?=r render_partial('footer.mt')
