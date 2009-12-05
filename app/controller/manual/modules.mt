? extends "base.mt";
? block content => sub {
? use Text::Markdown ()

<div class="markdown">
<?= raw_string(cache_get_callback( 'modules_list4' => sub { Text::Markdown::markdown(file_read(MENTA::base_dir().'/MODULES')) } )) ?>
</div>

? }
