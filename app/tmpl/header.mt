? my $title = shift
<!doctype html>
<title><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</title>
<link rel="stylesheet" type="text/css" href="<?= docroot ?>static/style-sites.css">
<div class="container">
<img src="<?= docroot ?>static/menta-logo.png" alt="Web Application Framework - MENTA" title="Web Application Framework - MENTA" />
<h1 class="maintitle"><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</h1>
<div class="bodyContainer">
