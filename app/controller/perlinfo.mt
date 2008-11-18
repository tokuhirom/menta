? use English
<!doctype html>
<h1>perl の情報</h1>
? use Data::Dumper
<h2>諸情報</h2>
<table>
<tr><th>OS</th><td><?= $OSNAME ?></td></tr>
<tr><th>Perl version</th><td><?= $] ?></td></tr>
<tr><th>Perlのパス</th><td><?= $EXECUTABLE_NAME ?></td></tr>
<tr><th>モジュールパス</th><td><?=r join "<br />", map { escape_html $_ } @INC ?></td></tr>
<tr><th>プロセスID</th><td><?= $$ ?></td></tr>
</table>
<h2>環境変数</h2>
<pre><?= Dumper(\%ENV) ?></pre>
