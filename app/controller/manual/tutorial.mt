? my $title = "MENTA 取り扱い説明書"
?= render('header.mt', $title)

<h2 class="subtitle">ダウンロードする</h2>
<div class="blocked-content">
インストール方法は<a href="<?= uri_for('manual/install') ?>">インストール方法解説ページ</a>を参考にしてください
</div>

<h2 class="subtitle">サーバーにアップロードする</h2>
<div class="blocked-content">
<p><code>MENTA/</code> ディレクトリをまるごとアップロードすれば OK です。</p>
</div>

<h2 class="subtitle">ディレクトリ構造</h2>
<div class="blocked-content">
<pre>app/            - あなたのアプリケーションをいれるところです
app/controller/ - あなたのアプリケーションそのものをいれます
app/data/       - あなたのアプリケーションのデータがはいります
app/static/     - 静的な画像やJavaScript, CSS などをいれます
extlib/         - 厳選されたCPANモジュールたち
lib/            - MENTA そのもの
plugins/        - MENTAプラグイン
t/              - MENTA 自体のテストスクリプト。ユーザーの方はきにする必要ありませぬ</pre>
</div>

<h2 class="subtitle">実際につかってみる</h2>
<div class="blocked-content">

<h3>Hello World してみる</h3>
? my $hello = 'app/controller/demo/hello.mt'
<p>下記のようなファイルを、<?= $hello ?> におきます。</p>
<pre><code><?= file_read(MENTA::base_dir() . $hello) ?></code></pre>
<p><code>param("user")</code> と書くと、<code><?= uri_for('demo/hello', { user => 'kazuhooku' }) ?></code> の <code>kazuhooku</code> の部分がとりだせます。</p>
<p><a href="<?= uri_for('demo/hello', { user => 'kazuhooku' }) ?>">実際にうごくデモ</a></p>

<h3>カウンターをつけてみる</h3>
? my $counter = 'app/controller/demo/counter.mt'
<pre><code><?= file_read(MENTA::base_dir() . $counter) ?></code></pre>
<p>このようにすると、カウンターを簡単に HTML の中にうめこめます。</p>
<p><code>counter_increment("test")</code> と書くと、<code>test</code> という名前のカウンターが 1 増えます。<code>counter_increment</code> の返却値として、1 増えた結果がかえってきますのでそのまま表示するだけでカウンターになります。</p>
<p><code>counter_increment()</code> という関数は <code>plugins/counter.pl</code> の中で定義されています。counter_* という関数を呼ぶと、自動的に <code>plugins/counter.pl</code> が読み込まれることになっています。</p>
<p><a href="<?= uri_for('demo/counter') ?>">実際にうごくデモ</a></p>

</div>

<!--
<h2 class="subtitle">プラグインの作り方</h2>
あとでかく。
-->

?= render('footer.mt')
