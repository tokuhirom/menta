package MENTA::TemplateLoader;
use strict;
use warnings;
use utf8;

# originaly code from NanoA::TemplateLoader

sub __load {
    my ($path, @params) = @_;
    my $out;
    if (__use_cache($path)) {
        my $tmplfname = main::mt_cache_dir . "/$path.c";
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
        $out = $tmplcode->();
        __update_cache($path, $code);
    }
    $out;
}

sub __compile {
    my ($path) = @_;
    MENTA::Util::require_once('MENTA/Template.pm');
    my $t = MENTA::Template->new;
    $t->parse(main::read_file($path));
    $t->build();
    my $code = $t->code();
    $code = << "EOT";
package main;
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
    my $cache_path = main::mt_cache_dir;
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
    return unless main::mt_cache_dir;
    my @orig = stat $path
        or return;
    my @cached = stat main::mt_cache_dir . "/${path}.c"
        or return;
    return $orig[9] < $cached[9];
}

"ENDOFMODULE";

