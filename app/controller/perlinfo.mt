? use English
? use Module::CoreList
<!doctype html>
<style>
.container { margin: auto; width: 400px }
th { background-color: #CCCCFF }
td { background-color: #CCCCCC }
h2 { text-align: center; }
table { text-align: left; }
</style>
<div class="container">
    <h1>MENTA <?= $MENTA::VERSION ?></h1>
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

    <h2>MENTA の設定</h2>
    <table>
    <tr><th>docroot</th><td><?= docroot ?></td></tr>
    <tr><th>controller_dir</th><td><?= controller_dir ?></td></tr>
    </table>

    <h2>MENTA標準添付モジュール</h2>
    <table>
? no strict 'refs'
? use UNIVERSAL::require
? for my $mod (sort { $a cmp $b } qw/JSON DateTime CGI::Simple Scalar::Util List::MoreUtils Path::Class URI Class::Accessor HTML::FillInForm Text::Hatena Data::Page HTML::TreeBuilder Text::CSV YAML Email::Send Email::MIME HTTP::MobileAgent HTML::TreeBuilder::XPath  Carp::Always Params::Validate HTML::StickyQuery::DoCoMoGUID UNIVERSAL::require Class::Trigger Text::Markdown HTTP::Session Filter::SQL/) {
?   $mod->require or die $@
    <tr><th><?= $mod ?></th><td><?= ${"${mod}::VERSION"} ?></td>
? }
    </table>

    <h2>Perl標準添付モジュール(perl <?= $] ?>)</h2>
    <table>
? my $modules = $Module::CoreList::version{$]}
? for my $key (sort keys %$modules) {
    <tr><th><?= $key ?></th><td><?= $modules->{$key} ?></td>
? }
    </table>
</div>
