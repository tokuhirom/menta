? my $title = "MENTA 取り扱い説明書"
?=r render_partial('header.mt', $title)

<h2 class="subtitle">ダウンロードする</h2>
<div class="blocked-content">
現状では svn export しか用意されていません。。。あとでなんとかします。<br />
<code><pre class="code">svn export http://svn.coderepos.org/share/lang/perl/MENTA/trunk/ MENTA</pre></code>としてください。
</div>

<h2 class="subtitle">サーバーにアップロードする</h2>
<div class="blocked-content">
MENTA/ ディレクトリをまるごとアップロードすれば OK です。<br />
</div>

<h2 class="subtitle">ディレクトリ構造</h2>
<div class="blocked-content">
XXX あとでかく XXX<br />
</div>

<h2 class="subtitle">実際につかってみる</h2>
<div class="blocked-content">

<h3>Hello World してみる</h3>
? my $hello = 'app/controller/hello.mt'

下記のようなファイルを、<?= $hello ?> におきます。

<code><pre class="code"><?= read_file($hello) ?></pre></code>

<p>
param("user") と書くと、<?= uri_for('hello', {user => 'kazuhooku'}) ?> の kazuhooku の部分がとりだせます。
</p>

<a href="<?= uri_for('hello', {user => 'kazuhooku'}) ?>">実際にうごいている様子</a>

<h3>カウンターをつけてみる</h3>

? my $counter = 'app/controller/counter.mt'

<code><pre class="code"><?= read_file($counter) ?></pre></code>

このようにすると、カウンターが簡単に HTML の中にうめこめます。

load_plugin('counter') と書くと、counter プラグインが読み込まれて、counter_increment() という名前の
関数が使えるようになります。counter_increment("test") と書くと、test という名前のカウンターが 1 増えます。
counter_increment の返却値として、１増えた結果がかえってきますのでそのまま表示するだけでカウンターになります。

<p><a href="<?= uri_for('counter') ?>">実際にうごいている様子</a></p>
</div>

<h2 class="subtitle">プラグインの作り方</h2>

あとでかく。

?=r render_partial('footer.mt')
