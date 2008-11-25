?= render('header.mt', "MENTA標準添付モジュールについて")
? use Text::Markdown ()
<div class="markdown">
<?=r Text::Markdown::markdown(file_read('MODULES')) ?>
</div>
?= render('footer.mt')
