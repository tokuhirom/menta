?=r render_partial('header.mt', "MENTA標準添付モジュールについて")
? use Text::Markdown ()

<pre><?=r Text::Markdown::markdown(read_file('MODULES')) ?></pre>

?=r render_partial('footer.mt')
