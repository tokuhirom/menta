? extends "base.mt";
? block title => "MENTA インストール方法";
? block content => sub {

<h2 class="subtitle">リリース版のダウンロード</h2>
<p><a href="http://github.com/tokuhirom/menta/downloads">最新リリース版 <?= $MENTA::VERSION ?> の ZIP アーカイブをダウンロード</a>できます。</p>
<p>リリース版は大きな変更が入る直前で更新されるため、致命的な既知のバグは取り除かれています。</p>

<h2 class="subtitle">開発版スナップショット</h2>
<p><a href="http://git-scm.com/">git</a> を使用して、<a href="http://github.com/tokuhirom/menta">http://github.com/tokuhirom/menta</a> からソースコードをエクスポートします。エクスポートしたディレクトリを HTTP でアクセス可能なディレクトリに移動すれば、動作を開始します。</p>
<p>以下の例では、<code>http://localhost/~user/menta/</code> といったディレクトリが MENTA のインストール先になります。</p>
<pre><code>% git clone git://github.com/tokuhirom/menta.git ~/public_html/menta</code></pre>

? };
