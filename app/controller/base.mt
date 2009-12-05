<!doctype html>
<head>
<title><? block title => "MENTA" ?></title>
<link rel="stylesheet" type="text/css" href="<?= static_file_path('style-sites.css') ?>">
</head>
<body>
<div class="container">
<a href="<?= docroot() ?>/" title="Web Application Framework - MENTA"><img src="<?= static_file_path('menta-logo.png') ?>" alt="MENTA"></a>
<h1 class="maintitle"><? block title => "MENTA" ?></h2>
<div class="bodyContainer">

<? block content => "" ?>

</div>
<p><a href="<?= uri_for('index') ?>">トップにもどる</a></p>
</div>
</body>
