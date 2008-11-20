?=r render_partial('header.mt', "MENTA標準添付モジュールについて")
? use Text::Markdown ()
<div class="markdown">
<?=r Text::Markdown::markdown(read_file('MODULES')) ?>
</div>
?=r render_partial('footer.mt')
