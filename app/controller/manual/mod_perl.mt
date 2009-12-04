? my $title = "MENTA 取り扱い説明書(mod_perl 編)"
?= render('header.mt', $title)

<h2 class="subtitle">MENTA の mod_perl 対応について</h2>
<div class="blocked-content">
MENTA は mod_perl に対応しています。サイトの負荷があがってきたから、高速な mod_perl 環境に移したい。そんな要望にもこたえられるのが MENTA です。
</div>

<h2 class="subtitle">MENTA の設定</h2>
<div class="blocked-content">基本的な設定は CGI で動かすときと一緒です。</div>

<h2 class="subtitle">Apache の設定</h2>
<div class="blocked-content">
httpd.conf など apache の設定ファイルの中に下記のように書きましょう。パスは適当に自分のものに差し替えてください。
<pre>
&lt;Perl&gt;
    use lib "/var/www/menta/lib/", '/var/www/menta/extlib/';
&lt;/Perl&gt;
&lt;Location /menta/&gt;
    SetHandler perl-script
    PerlResponseHandler Plack::Server::Apache2
    PerlSetVar psgi_app /path/to/menta.psgi
&lt;/Location&gt;

&lt;Perl&gt;
use Plack::Server::Apache2;
Plack::Server::Apache2->preload("/path/to/menta.psgi");
&lt;/Perl&gt;

</pre>

</div>

?= render('footer.mt')
