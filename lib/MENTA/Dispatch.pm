package MENTA::Dispatch;
use strict;
use warnings;
use utf8;

sub dispatch {
    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s!^/+!!g;
    if ($path =~ m{^[a-z0-9_/]+$}) {
        $path ||= 'index';
        my $cdir = main::controller_dir();
        my $controller = "${cdir}/${path}.pl";
        my $controller_mt = "${cdir}/${path}.mt";
        if (-f $controller) {
            my $meth = "do_$path";
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
            my $out = main::__render_partial("${path}.mt", main::controller_dir());
            $out = main::encode_output($out);
            print "Content-Type: text/html; charset=" . main::charset() . "\r\n";
            print "\r\n";
            print $out;
        } else {
            die "「${path}」というモードは存在しません。コントローラファイルもありません(${controller})。テンプレートファイルもありません(${controller_mt})";
        }
    } elsif ($path ne 'menta.cgi' && -f "app/$path" && $path =~ /^static\//) {
        show_static("app/$path");
    } elsif ($path =~ /^(?:crossdomain\.xml|favicon\.ico|robots\.txt)$/) {
        print "status: 404\r\ncontent-type: text/plain\r\n\r\n";
    } else {
        die "${path} を処理する方法がわかりません";
    }
}

sub show_static {
    my $path = shift;
    open my $fh, '<', $path or die "ファイルを開けません: ${path}: $!";
    binmode $fh;
    binmode STDOUT;
    printf "Content-Type: %s\r\n\r\n", guess_mime_type($path);
    print do { local $/; <$fh> };
    close $fh;
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

"END OF MODULE";
