#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use lib 'vender/lib/', 'lib';
use Config::Tiny;
use Data::Dumper;
use Mojo::Template;
use MENTA::Util;

binmode STDOUT, ':utf8';

my $OUTPUT_DIR = 'out/';
my $SOURCE_DIR = 'users/';

&main; exit;

sub replace {
    my ($src, $params) = @_;
    while (my ($key, $val) = each %$params) {
        $src =~ s/### $key ###/$val/g;
    }
    $src;
}

sub main {
    say "出力先ディレクトリを作成しています";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;

    say "メインソースをコンパイルします";
    sub {
        say "ソースファイルを読み込んでいます";
        my $menta = read_file('src/menta.pl');
        say ".ini ファイルを読んでいます";
        my $ini = Config::Tiny->read("$SOURCE_DIR/config.ini") or die "$SOURCE_DIR/config.ini を読み込むことができませんでした: $!";

        say "index.cgi をつくりあげる";
        $menta = replace($menta, {
            CONFIG => do {
                local $Data::Dumper::Indent = 1;
                local $Data::Dumper::Terse  = 1;
                local $Data::Dumper::Sortkeys = 1;
                q{$MENTA::CONFIG = } . Data::Dumper->Dump([{%$ini}]) . q{;};
            },
            MAIN => do {
                '{' . read_file('lib/MENTA.pm') . '}'
            },
            CONTROLLER => do {
                '{' . read_file('users/controller.pl') . '}'
            },
            SHEBANG => do {
                my $perlpath = $ini->{menta}->{perlpath} or die "config.ini の [menta] の中に perl のパスに関する設定がありません";
                "#!$perlpath";
            },
        });
        say "index.cgi を出力しています";
        write_file("$OUTPUT_DIR/index.cgi" => $menta);
        say "chmod +x";
        chmod oct(766), "$OUTPUT_DIR/index.cgi";
    }->();

    say "テンプレートファイルをコンパイルします";
    sub {
        mkdir "$OUTPUT_DIR/tmpl";
        opendir my $dir, "$SOURCE_DIR/tmpl" or die "テンプレートファイル用ディレクトリを開けません: $!";
        while (my $file = readdir $dir) {
            my $fname = "$SOURCE_DIR/tmpl/$file";
            next unless -f $fname;
            my $src = read_file($fname);
            my $mt = Mojo::Template->new;
            $mt->parse($src);
            $mt->build();
            my $code = $mt->code();
            write_file("$OUTPUT_DIR/tmpl/$file", "use utf8;\n$code");
        }
        closedir $dir;
    }->();
}

