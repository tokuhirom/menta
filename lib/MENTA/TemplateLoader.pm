package MENTA::TemplateLoader;
use strict;
use warnings;
use utf8;

# originaly code from NanoA::TemplateLoader

sub __load {
    my ($path, @params) = @_;
    my $out;
    if (__use_cache($path)) {
        my $tmplfname = MENTA::mt_cache_dir . "/$path.c";
        local $@;
        my $tmplcode = do $tmplfname;
        die $@ if $@;
        die "テンプレートキャッシュを読み込めませんでした: ${tmplfname}($!)" unless $tmplcode;
        $out = $tmplcode->(@params);
    } else {
        my $code = __compile($path);
        local $@;
        my $tmplcode = eval $code;
        die $@ if $@;
        $out = $tmplcode->(@params);
        __update_cache($path, $code);
    }
    $out;
}

sub __compile {
    my ($path) = @_;
    MENTA::Util::require_once('MENTA/Template.pm');
    my $src = do {
        open my $fh, '<:utf8', $path or die "${path} を読み込み用に開けません: $!";
        my $s = do { local $/; join '', <$fh> };
        close $fh;
        $s;
    };
    my $t = MENTA::Template->new;
    $t->parse($src);
    $t->build();
    my $code = $t->code();
    $code = << "EOT";
package MENTA::TemplateLoader::Instance;
use strict;
use warnings;
use utf8;
$code
EOT
;
    $code;
}

sub __update_cache {
    my ($path, $code) = @_;
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
    for my $meth (qw/escape_html unescape_html config render param mobile_agent uri_for static_file_path docroot AUTOLOAD redirect current_url/) {
        *{__PACKAGE__ . '::' . $meth} = *{"MENTA::$meth"};
    }
}

"ENDOFMODULE";

