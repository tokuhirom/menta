? extends "base.mt";
? block title => "MENTA のパフォーマンス";

? block content => sub {

<h2>2009-12-06 時点でのパフォーマンス</h2>

<h3>テンプレートエンジンをつかわない場合のパフォーマンス</h3>

<h4>Apache + CGI の場合</h4>

<pre>
/usr/sbin/ab -c 10 -n 1000  http://127.0.0.1/menta/menta.cgi/demo/helloworld
</pre>
で
<pre>
Requests per second:    32.57 [#/sec] (mean)
</pre>
です。

<h4>永続的環境におけるパフォーマンス<h4>

<pre>
plackup -E production -s Standalone::Prefork -p 5555 menta.psgi
</pre>
のようにして、Plack::Server::Standalone::Prefork をつかってベンチマークをとると、
<pre>
/usr/sbin/ab -c 10 -n 1000 http://127.0.0.1:5555/demo/helloworld
</pre>
のようにベンチをとると、
<pre>
Requests per second:    1395.25 [#/sec] (mean)
</pre>
ぐらいのパフォーマンスがでます。

? };
