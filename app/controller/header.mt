? my $title = shift
<!doctype html>
<head>
<title><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</title>
<link rel="stylesheet" type="text/css" href="<?= static_file_path('style-sites.css') ?>">
</head>
<body>
<div class="container">
<a href="<?= docroot() ?>/" title="Web Application Framework - MENTA"><img src="<?= static_file_path('menta-logo.png') ?>" alt="MENTA"></a>
<h1 class="maintitle"><? if ($title) { ?><?= "$title - " ?><? } ?>MENTA</h1>
<div class="bodyContainer">
