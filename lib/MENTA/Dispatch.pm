package MENTA::Dispatch;
use strict;
use warnings;
use utf8;

sub dispatch {
    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s!^/+!!g;
    $path ||= 'index';
    if ($path =~ m{^[a-z0-9_/]+$}) {
        my $cdir = main::controller_dir();
        my $controller = "${cdir}/${path}.pl";
        my $controller_mt = "${cdir}/${path}.mt";
        if (-f $controller) {
            my $meth = $path;
            $meth =~ s!^.+/!!;
            $meth = "do_$meth";
            package main;
            do $controller;
            if (my $e = $@) {
                if (ref $e) {
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
            MENTA::Util::require_once('MENTA/TemplateLoader.pm');
            my $tmpldir = main::controller_dir();
            my $out = MENTA::TemplateLoader::__load("${tmpldir}/${path}.mt", main::controller_dir());
            $out = MENTA::Util::encode_output($out);
            main::finalize($out);
        } else {
            die "「${path}」というモードは存在しません。コントローラファイルもありません(${controller})。テンプレートファイルもありません(${controller_mt})";
        }
    } elsif ($path ne 'menta.cgi' && -f "app/$path" && $path =~ /^static\//) {
        show_static("app/$path");
    } elsif ($path =~ /^(?:crossdomain\.xml|favicon\.ico|robots\.txt)$/) {
        print "status: 404\r\ncontent-type: text/plain\r\n\r\n";
    } else {
        die "'${path}' を処理する方法がわかりません";
    }
}

sub show_static {
    my $path = shift;
    MENTA::Util::require_once('Cwd.pm');
    MENTA::Util::require_once('File/Spec.pm');
    $path = Cwd::realpath($path);
    my $appdir = Cwd::realpath(File::Spec->catfile(Cwd::cwd(), 'app', 'static'));
    if (index($path, $appdir) != 0) {
        die "どうやら攻撃されているようだ: $path";
    }
    open my $fh, '<:raw', $path or die "ファイルを開けません: ${path}: $!";
    binmode STDOUT;
    printf "Content-Length: %d\r\n", -s $path;
    printf "Content-Type: %s\r\n\r\n", guess_mime_type($path);
    print do { local $/; <$fh> };
    close $fh;
}

sub guess_mime_type {
    my $ext = shift;
    $ext =~ s/.+\.([^.]+)$/$1/;

    # TODO should be moved to other.
    my $mime_map = {
        css  => 'text/css',
        gif  => 'image/gif',
        jpeg => 'image/jpeg',
        jpg  => 'image/jpeg',
        js   => 'application/javascript',
        png  => 'image/png',
        txt  => 'text/plain',
    };
    $mime_map->{$ext} || 'application/octet-stream';
}

"END OF MODULE";
