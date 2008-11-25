?= render_partial('header.mt', 'インストール方法')

<h2 class="subtitle">開発版スナップショットのダウンロード</h2>

<p><a href="http://coderepos.org/share/changeset/HEAD/lang/perl/MENTA/tags/release-<?= $MENTA::VERSION ?>?old_path=%2F&format=zip">こちら</a>からダウンロードできます。</p>

<p>開発版スナップショットは、大きな変更が入る直前で更新されるため、致命的な既知のバグは取り除かれています</p>

<h2 class="subtitle">開発版のダウンロード</h2>

<p>
Subversion を使用して、svn.coderepos.org/share/lang/perl/MENTA/trunk からソースコードをダウンロードします。ダウンロードしたディレクトリを HTTP アクセス可能なディレクトリに移動すれば、動作を開始します。
</p>

<p>以下の例では、http://host/~user/menta/ というディレクトリが、MENTA のインストール先になります。</p>

<pre class="code">% svn co http://svn.coderepos.org/share/lang/perl/MENTA/trunk
% mv trunk ~/public_html/menta</pre>

?= render_partial('footer.mt')

