?=r render_partial('header.mt', 'インストール方法')

開発版のダウンロード

Subversion を使用して、svn.coderepos.org/share/lang/perl/MENTA/trunk からソースコードをダウンロードします。ダウンロードしたディレクトリを HTTP アクセス可能なディレクトリに移動すれば、動作を開始します。

以下の例では、http://host/~user/menta/ というディレクトリが、MENTA のインストール先になります。

<pre class="code">% svn co http://svn.coderepos.org/share/lang/perl/MENTA/trunk
% mv trunk ~/public_html/menta</pre>

?=r render_partial('footer.mt')

