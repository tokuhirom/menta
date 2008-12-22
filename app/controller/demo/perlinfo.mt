? use English;
? use Module::CoreList;
<!doctype html>
<head>
<title>MENTA Perl information</title>
<style type="text/css">
.container { margin: auto; width: 400px }
h2 { text-align: center }
table { text-align: left }
th { background-color: #CCCCFF }
td { background-color: #CCCCCC }
</style>
</head>

<div class="container">
    <h1>MENTA <?= $MENTA::VERSION ?></h1>
    <h2>諸情報</h2>
    <table>
    <tr><th>OS</th><td><?= $OSNAME ?></td></tr>
    <tr><th>Perl version</th><td><?= $] ?></td></tr>
    <tr><th>Perlのパス</th><td><?= $EXECUTABLE_NAME ?></td></tr>
    <tr><th>モジュールパス</th><td><?= raw_string(join '<br>', map { escape_html $_ } @INC) ?></td></tr>
    <tr><th>プロセスID</th><td><?= $$ ?></td></tr>
    </table>
    <h2>環境変数</h2>
    <table>
? while (my ($key, $val) = each %ENV) {
    <tr><th><?= $key ?></th><td><?= $val ?></td>
? }
    </table>

    <h2>MENTA の設定</h2>
    <table>
    <tr><th>docroot</th><td><?= docroot() ?></td></tr>
    <tr><th>controller_dir</th><td><?# controller_dir ?></td></tr>
    </table>

    <h2>MENTA標準添付モジュール</h2>
    <table>
? my @vers = bundle_libs();
? while (my ($key, $val) = splice(@vers, 0, 2)) {
    <tr><th><?= $key ?></th><td><?= $val ?></td>
? }
    </table>

    <h2>Perl標準添付モジュール(perl <?= $] ?>)</h2>
    <table>
? my $modules = $Module::CoreList::version{$]};
? for my $key (sort keys %$modules) {
    <tr><th><?= $key ?></th><td><?= $modules->{$key} || '' ?></td>
? }
    </table>
</div>
