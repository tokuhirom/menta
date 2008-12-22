package MENTA::TemplateLoader;
use strict;
use warnings;
use utf8;

# originaly code from NanoA::TemplateLoader

sub __load {
    my ($path, @params) = @_;

    if (__use_cache($path)) {
        my $tmplfname = MENTA::mt_cache_dir . "/$path.c";
        local $@;
        my $tmplcode = do $tmplfname;
        die $@ if $@;
        die "テンプレートキャッシュを読み込めませんでした: ${tmplfname}($!)" unless $tmplcode;
        return $tmplcode->(@params)->as_string;
    } else {
        return __compile($path, @params);
    }
}

sub __compile {
    my ($path, @params) = @_;
    MENTA::Util::require_once('Text/MicroTemplate/File.pm');

    my $mtf = Text::MicroTemplate::File->new(
        include_path => [MENTA::controller_dir()],
        package_name => 'MENTA::TemplateLoader::Instance',
    );
    my $out = $mtf->build_file($path)->(@params)->as_string;
    __update_cache($path, $mtf->code);
    return $out;
}

sub __update_cache {
    my ($path, $code) = @_;

    $code = <<"...";
package MENTA::TemplateLoader::Instance;
sub {
    local \$SIG{__WARN__} = sub { print STDERR \$_mt->_error(shift, 4, \$_from) };
    Text::MicroTemplate::encoded_string((
        $code
    )->(\@_));
}
...

    my $cache_path = MENTA::mt_cache_dir;
    foreach my $p (split '/', $path) {
        mkdir $cache_path;
        $cache_path .= "/$p";
    }
    $cache_path .= '.c';
    open my $fh, '>:utf8', $cache_path
        or die "キャッシュファイルを作れません: $cache_path($!)";
    print $fh $code;
    close $fh;
}

sub __use_cache {
    my ($path) = @_;
    return unless MENTA::mt_cache_dir;
    my @orig = stat $path
        or return;
    my @cached = stat MENTA::mt_cache_dir . "/${path}.c"
        or return;
    return $orig[9] < $cached[9];
}

{
    package MENTA::TemplateLoader::Instance;
    no strict 'refs';
    for my $meth (qw/escape_html unescape_html raw_string config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect current_url/) {
        *{__PACKAGE__ . '::' . $meth} = *{"MENTA::$meth"};
    }
}

"ENDOFMODULE";

