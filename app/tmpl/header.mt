? my $title = shift
<!doctype html>
<title><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</title>
<link rel="stylesheet" type="text/css" href="<?= docroot ?>static/style-sites.css">
<div class="container">
<h1><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</h1>
<div class="bodyContainer">
