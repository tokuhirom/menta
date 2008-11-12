package MENTA::Builder;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Mojo::Template;
use MENTA::Util;

my $OUTPUT_DIR = 'out/';
my $SOURCE_DIR = 'users/';

sub replace {
    my ($src, $params) = @_;
    while (my ($key, $val) = each %$params) {
        $src =~ s/### $key ###/$val/g;
    }
    $src;
}

sub run {
    say "出力先ディレクトリを作成しています";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;

    say "メインソースをコンパイルします";
    sub {
        say "ソースファイルを読み込んでいます";
        my $menta = read_file('src/menta.pl');
        say ".ini ファイルを読んでいます";
        do 'users/controller.pl';
        die $@ if $@;

        say "index.cgi をつくりあげる";
        $menta = replace($menta, {
            MAIN => do {
                "{\n" . read_file('lib/MENTA.pm') . '}'
            },
            CONTROLLER_BASE => do {
                '{' . read_file('lib/MENTA/Controller/Base.pm') . '}'
            },
            CONTROLLER => do {
                '{' . read_file('users/controller.pl') . '}'
            },
            SHEBANG => do {
                my $perlpath = $MENTA::CONFIG->{menta}->{perlpath} or die "config.ini の [menta] の中に perl のパスに関する設定がありません";
                "#!$perlpath";
            },
        });
        $menta =~ s/use MENTA::Base;/package main;/g;
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

1;
