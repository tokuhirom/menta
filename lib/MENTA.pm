package MENTA;
use strict;
use warnings;
use utf8;
use CGI::ExceptionManager;

our $VERSION = '0.05';
our $REQ;
our $CONFIG;
our $REQUIRED;
our $MOBILEAGENTRE;
our $CARRIER;
our $STASH;
our $PLUGIN_LOADED;
BEGIN {
    $REQUIRED = {};
}

sub import {
    strict->import;
    warnings->import;
    utf8->import;
}

package main; # ここ以下の関数はすべてコントローラで呼ぶことができます

sub config () { $MENTA::CONFIG }

sub run_menta {
    my $config = shift @_;

    local $MENTA::CONFIG = $config;
    local $MENTA::REQ;
    local $MENTA::STASH;

    CGI::ExceptionManager->run(
        callback => sub {
            dispatch()
        },
        powered_by => '<strong>MENTA</strong>, Web Application Framework.',
        (config->{menta}->{fatals_to_browser} ? () : (renderer => sub { "INTERNAL SERVER ERROR!" x 100 }))
    );
}

sub dispatch {
    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s!^/+!!g;
    if ($path =~ /^[a-z0-9_]*$/) {
        $path ||= 'index';
        my $cdir = controller_dir();
        my $controller = "${cdir}/${path}.pl";
        my $controller_mt = controller_dir() . "/${path}.mt";
        if (-f $controller) {
            my $meth = "do_$path";
            package main;
            do $controller;
            if (my $e = $@) {
                if (ref $e) {
                    warn "KTKR";
                    return;
                } else {
                    die $e;
                }
            }
            die $@ if $@;
            if (my $code = main->can($meth)) {
                $code->();
                die "なにも出力してません";
            } else {
                die "「${path}」というモードは存在しません!${controller} の中に ${meth} が定義されていないようです";
            }
        } elsif (-f $controller_mt) {
            my $out = __render_partial("${path}.mt", controller_dir());
            utf8::encode($out);
            print "Content-Type: text/html; charset=utf-8\r\n";
            print "\r\n";
            print $out;
        } else {
            die "「${path}」というモードは存在しません。コントローラファイルもありません(${controller})。テンプレートファイルもありません(${controller_mt})";
        }
    } elsif ($path ne 'menta.cgi' && -f "app/$path") {
        $path = "app/$path";
        if (open my $fh, '<', $path) {
            binmode $fh;
            binmode STDOUT;
            printf "Content-Type: %s\r\n\r\n", guess_mime_type($path);
            print do { local $/; <$fh> };
            close $fh;
        } else {
            die "ファイルが開きません";
        }
    } elsif ($path =~ /^(?:crossdomain\.xml|favicon\.ico|robots\.txt)$/) {
        print "status: 404\r\ncontent-type: text/plain\r\n\r\n";
    } else {
        die "${path} を処理する方法がわかりません";
    }
}

sub escape_html {
    local $_ = shift;
    return $_ unless $_;
    s/&/&amp;/g;
    s/>/&gt;/g;
    s/</&lt;/g;
    s/"/&quot;/g;
    s/'/&#39;/g;
    return $_;
}

sub unescape_html {
    local $_ = shift;
    return $_ unless $_;
    s/&gt;/>/g;
    s/&lt;/</g;
    s/&quot;/"/g;
    s/&#39;/'/g;
    s/&amp;/&/g;
    return $_;
}

sub guess_mime_type {
    my $ext = shift;
    $ext =~ s/.+\.(.+)$/$1/;

    # TODO should be moved to other.
    my $mime_map = {
        css => 'text/css',
        js  => 'application/javascript',
        jpg => 'image/jpeg',
        gif => 'image/gif',
        png => 'image/png',
        txt => 'text/plain',
    };
    $mime_map->{$ext} || 'application/octet-stream';
}

sub cache_dir {
    config->{menta}->{cache_dir} || 'cache'
}

sub tmpl_dir {
    config->{menta}->{cache_dir} || 'app/tmpl/'
}

sub controller_dir {
    config->{menta}->{controller_dir} || 'app/controller/'
}

sub data_dir {
    config->{menta}->{data_dir} || 'app/data/'
}

sub static_dir {
    config->{menta}->{static_dir} || 'app/static/'
}

# TODO: ディレクトリトラバーサル対策
sub __render_partial {
    my ($tmpl, $tmpldir, @params) = @_;
    my $conf = config()->{menta};
    my $cachedir = cache_dir();
    mkdir $cachedir unless -d $cachedir;
    my $cachefname = "$cachedir/$tmpl";
    my $tmplfname = "$tmpldir/$tmpl";
    my $use_cache = sub {
        my @orig = stat $tmplfname or return;
        my @cached = stat $cachefname or return;
        return $orig[9] < $cached[9];
    }->();
    my $out;
    if ($use_cache) {
        my $tmplcode = do $cachefname;
        die $@ if $@;
        die "テンプレートキャッシュを読み込めませんでした: ${tmplfname}" unless $tmplcode;
        $out = $tmplcode->(@params);
    } else {
        die "「${tmplfname}」という名前のテンプレートファイルは見つかりません" unless -f $tmplfname;
        require_once('MENTA/Template.pm');
        my $tmplsrc = read_file($tmplfname);
        my $mt = MENTA::Template->new;
        $mt->parse($tmplsrc);
        $mt->build();
        my $src = $mt->code();
        my $tmplcode = eval $src;
        die $@ if $@;
        $out = $tmplcode->(@params);
        write_file($cachefname, "package main; use utf8;\n${src}");
    }
    $out;
}
sub render_partial {
    my ($tmpl, @params) = @_;
    __render_partial($tmpl, tmpl_dir(), @params);
}

sub detach() { CGI::ExceptionManager::detach(@_) }

sub render {
    my ($tmpl, @params) = @_;
    my $out = render_partial($tmpl, @params);
    utf8::encode($out);
    print "Content-Type: text/html; charset=utf-8\r\n";
    print "\r\n";
    print $out;

    detach;
}

sub redirect {
    my ($location, ) = @_;
    print "Status: 302\r\n";
    print "Location: $location\r\n";
    print "\r\n";

    detach;
}

sub finalize {
    my $str = shift;
    my $content_type = shift || 'text/html; charset=utf-8';

    print "Content-Type: $content_type\r\n";
    print "\r\n";
    print $str;

    detach;
}

sub read_file {
    my $fname = shift;
    open my $fh, '<:utf8', $fname or die "${fname} を読み込み用に開けません: $!";
    my $s = do { local $/; join '', <$fh> };
    close $fh;
    $s;
}

sub write_file {
    my ($fname, $stuff) = @_;
    open my $fh, '>:utf8', $fname or die "${fname} を書き込み用に開けません: $!";
    print $fh $stuff;
    close $fh;
}

sub param {
    my $key = shift;

    unless (defined $MENTA::REQ) {
        require_once('CGI/Simple.pm');
        $CGI::Simple::PARAM_UTF8++;
        $MENTA::REQ = CGI::Simple->new();
    }

    $MENTA::REQ->param($key);
}

sub upload {
    unless (defined $MENTA::REQ) {
        require_once('CGI/Simple.pm');
        $CGI::Simple::PARAM_UTF8++;
        $MENTA::REQ = CGI::Simple->new();
    }
    $MENTA::REQ->upload(@_);
}

sub require_once {
    my $path = shift;
    return if $MENTA::REQUIRED->{$path};
    require $path;
    $MENTA::REQUIRED->{$path} = 1;
}

sub load_plugin {
    my $plugin = shift;
    return if $MENTA::PLUGIN_LOADED->{$plugin};
    my $path = "plugins/${plugin}.pl";
    require $path;
    $MENTA::PLUGIN_LOADED->{$plugin}++;
    my $package = __menta_extract_package($path) || '';
    no strict 'refs';
    for (
        grep { /$plugin/o }
        grep { defined &{"${package}::$_"} }
        keys %{"${package}::"}
    ) {
        *{"main::$_"} = *{"${package}::$_"}
    }
}

sub __menta_extract_package {
    my $modulefile = shift;
    open my $fh, '<', $modulefile or die "$modulefile を開けません: $!";
    my $in_pod = 0;
    while (<$fh>) {
        $in_pod = 1 if m/^=\w/;
        $in_pod = 0 if /^=cut/;
        next if ( $in_pod || /^=cut/ );    # skip pod text
        next if /^\s*\#/;

        /^\s*package\s+(.*?)\s*;/ and return $1;
    }
    return;
}

sub is_post_request () {
    my $method = $ENV{REQUEST_METHOD};
    return $method eq 'POST';
}

# TODO: CGI にはこのための環境変数ってなかったっけ?
sub docroot () { $ENV{SCRIPT_NAME} || '' }

sub uri_for {
    my ($path, $query) = @_;
    my @q;
    while (my ($key, $val) = each %$query) {
        $val = join '', map { /^[a-zA-Z0-9_.!~*'()-]$/ ? $_ : '%' . uc(unpack('H2', $_)) } split //, $val;
        push @q, "${key}=${val}";
    }
    docroot . '/' . $path . (scalar @q ? '?' . join('&', @q) : '');
}

sub static_file_path {
    my $path = shift;
    docroot . '/static/' . $path;
}

1;
