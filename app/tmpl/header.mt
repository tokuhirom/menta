? my $title = shift
<!doctype html>
<title><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</title>
<link rel="stylesheet" type="text/css" href="<?= static_file_path('style-sites.css') ?>">
<div class="container">
<img src="<?= static_file_path('menta-logo.png') ?>" alt="Web Application Framework - MENTA" title="Web Application Framework - MENTA" />
<h1 class="maintitle"><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</h1>
<div class="bodyContainer">
