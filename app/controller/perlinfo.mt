? use English
? use Data::Dumper
<!doctype html>
<style>
.container { margin: auto; width: 400px }
th { background-color: #CCCCFF }
td { background-color: #CCCCCC }
h2 { text-align: center; }
</style>
<div class="container">
    <h1>perl の情報</h1>
    <h2>諸情報</h2>
    <table>
    <tr><th>OS</th><td><?= $OSNAME ?></td></tr>
    <tr><th>Perl version</th><td><?= $] ?></td></tr>
    <tr><th>Perlのパス</th><td><?= $EXECUTABLE_NAME ?></td></tr>
    <tr><th>モジュールパス</th><td><?=r join "<br />", map { escape_html $_ } @INC ?></td></tr>
    <tr><th>プロセスID</th><td><?= $$ ?></td></tr>
    </table>
    <h2>環境変数</h2>
    <table>
? while (my ($key, $val) = each %ENV) {
    <tr><th><?= $key ?></th><td><?= $val ?></td>
? }
    </table>
</div>
