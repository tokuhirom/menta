? my $title = "MENTA 取り扱い説明書(mod_perl 編)"
?= render('header.mt', $title)

<h2 class="subtitle">MENTA の mod_perl 対応について</h2>
<div class="blocked-content">
MENTA は mod_perl に対応しています。サイトの負荷があがってきたから、高速な mod_perl 環境に移したい。そんな要望にもこたえられるのが MENTA です。
</div>

<h2 class="subtitle">MENTA の設定</h2>
<div class="blocked-content">
基本的な設定は CGI で動かすときと一緒です。が、設定を config.pl などという名前で、別ファイルにする必要があります。詳しくは、MENTA の配布
パッケージに入っている config.pl をみてください。
</div>

<h2 class="subtitle">Apache の設定</h2>
<div class="blocked-content">
httpd.conf など apache の設定ファイルの中に下記のように書きましょう。パスは適当に自分のものに差し替えてください。
<pre>
&lt;Perl&gt;
    use lib "/var/www/menta/lib/", '/var/www/menta/extlib/';
&lt;/Perl&gt;
&lt;Location /menta/&gt;
    SetHandler modperl
    PerlOptions +SetupEnv
    PerlResponseHandler MENTA::ModPerl
    PerlSetVar MENTA_CONFIG_PATH /var/www/menta/config.pl
&lt;/Location&gt;
</pre>

</div>

?= render('footer.mt')
