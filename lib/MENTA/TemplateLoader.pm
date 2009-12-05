package MENTA::TemplateLoader;
use strict;
use warnings;
use utf8;

# originaly code from NanoA::TemplateLoader

sub __load {
    my ($path, @params) = @_;

    MENTA::Util::require_once('Text/MicroTemplate/File.pm');

    my $mtf = Text::MicroTemplate::File->new(
        include_path => [MENTA::controller_dir()],
        package_name => 'MENTA::TemplateLoader::Instance',
        cache        => 1,
    );
    return $mtf->render_file($path, @params)->as_string;
}

{
    package MENTA::TemplateLoader::Instance;
    no strict 'refs';
    for my $meth (qw/escape_html unescape_html raw_string config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect current_url/) {
        *{__PACKAGE__ . '::' . $meth} = *{"MENTA::$meth"};
    }
}

"ENDOFMODULE";
