?= render('header.mt', 'インストール方法')

<h2 class="subtitle">リリース版のダウンロード</h2>
<p><a href="http://coderepos.org/share/changeset/HEAD/lang/perl/MENTA/tags/release-<?= $MENTA::VERSION ?>?old_path=%2F&amp;format=zip">最新リリース版 <?= $MENTA::VERSION ?> の ZIP アーカイブをダウンロード</a>できます。</p>
<p>リリース版は大きな変更が入る直前で更新されるため、致命的な既知のバグは取り除かれています。</p>

<h2 class="subtitle">開発版スナップショット</h2>
<p>Subversion を使用して、<code>http://svn.coderepos.org/share/lang/perl/MENTA/trunk</code> からソースコードをエクスポートします。エクスポートしたディレクトリを HTTP でアクセス可能なディレクトリに移動すれば、動作を開始します。</p>
<p>以下の例では、<code>http://localhost/~user/menta/</code> といったディレクトリが MENTA のインストール先になります。</p>
<pre><code>% svn export http://svn.coderepos.org/share/lang/perl/MENTA/trunk ~/public_html/menta</code></pre>

?= render('footer.mt')
