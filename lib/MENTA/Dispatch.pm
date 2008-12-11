package MENTA::Dispatch;
use strict;
use warnings;
use utf8;

sub dispatch {
    my $path = $ENV{PATH_INFO} || '/';
    $path =~ s!^/+!!g;
    $path ||= 'index';
    if ($path =~ m{^plugin/([a-z0-9_-]+)/([a-z0-9_]+)$}) {
        my ($plugin_name, $meth) = ($1, $2);
        $meth = "do_$meth";
        my $pkg = MENTA::Util::load_plugin($plugin_name);
        $pkg->$meth();
    } elsif ($path =~ m{^[a-z0-9_/]+$}) {
        $path =~ s!/$!/index!;
        my $cdir = MENTA::controller_dir();
        my $controller = "${cdir}/${path}.pl";
        my $controller_mt = "${cdir}/${path}.mt";
        if (-f $controller) {
            my $pkg = do $controller;
            if (my $e = $@) {
                if (ref $e) {
                    warn $e;
                    return;
                } else {
                    die $e;
                }
            }
            die $@ if $@;
            if (my $code = $pkg->run()) {
                $code->();
                die "なにも出力してません";
            } else {
                die "${controller} の中に run 関数が定義されていないようです";
            }
        } elsif (-f $controller_mt) {
            MENTA::Util::require_once('MENTA/TemplateLoader.pm');
            my $tmpldir = MENTA::controller_dir();
            my $out = MENTA::TemplateLoader::__load("${path}.mt", MENTA::controller_dir());
            $out = MENTA::Util::encode_output($out);
            MENTA::finalize($out);
        } else {
            die "「${path}」というモードは存在しません。コントローラファイルもありません(${controller})。テンプレートファイルもありません(${controller_mt})。ベースディレクトリは @{[ MENTA::base_dir() ]} です。";
        }
    } elsif ($path ne 'menta.cgi' && -f (MENTA::base_dir() . "app/$path") && $path =~ /^static\//) {
        show_static("app/$path");
    } elsif ($path =~ /^(?:crossdomain\.xml|favicon\.ico|robots\.txt)$/) {
        print "status: 404\r\ncontent-type: text/plain\r\n\r\n";
    } else {
        die "'${path}' を処理する方法がわかりません(@{[ MENTA::base_dir() . 'app/' . $path ]})";
    }
}

sub show_static {
    my $path = shift;
    MENTA::Util::require_once('Cwd.pm');
    MENTA::Util::require_once('File/Spec.pm');
    MENTA::Util::require_once('CGI/Simple/Util.pm');
    $path = Cwd::realpath(File::Spec->catfile(MENTA::base_dir(), $path));
    my $appdir = Cwd::realpath(File::Spec->catfile(MENTA::base_dir(), 'app', 'static'));
    if (index($path, $appdir) != 0) {
        die "どうやら攻撃されているようだ: $path";
    }
    open my $fh, '<:raw', $path or die "ファイルを開けません: ${path}: $!";
    my $res = HTTP::Engine::Response->new(
        status => 200,
        body   => do { local $/; <$fh> },
    );
    $res->content_type(guess_mime_type($path));
    $res->header( Expires => CGI::Simple::Util::expires('+1d') );
    CGI::ExceptionManager::detach($res);
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
