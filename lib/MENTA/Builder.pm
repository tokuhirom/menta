package MENTA::Builder;
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Mojo::Template;
use MENTA::Util;

my $OUTPUT_DIR = 'out/';
my $SOURCE_DIR = 'app/';

sub replace {
    my ($src, $params) = @_;
    $src =~ s{###\s+INCLUDE\s+'([^']+)'\s+###}{
        my $fname = $1;
        "{\n" . read_file($fname) . "}\n"
    }gem;
    while (my ($key, $val) = each %$params) {
        $src =~ s/### $key ###/$val/g;
    }
    $src;
}

sub run {
    say "出力先ディレクトリを作成しています";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;

    say "メインソースをコンパイルします";
    generate_cgi();

    say "テンプレートファイルをコンパイルします";
    generate_template_files();
}

sub generate_cgi {
    say "ソースファイルを読み込んでいます";
    my $menta = read_file('src/menta.pl');

    say "index.cgi をつくりあげる";
    $menta = replace($menta, {
        SHEBANG => do {
            my ($shebang,) = split /\n/, read_file('app/index.cgi');
            $shebang;
        },
    });
    $menta =~ s/use MENTA::Base;/package main;/g;
    say "index.cgi を出力しています";
    write_file("$OUTPUT_DIR/index.cgi" => $menta);
    say "chmod +x";
    chmod oct(766), "$OUTPUT_DIR/index.cgi";
}

sub generate_template_files {
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
        write_file("$OUTPUT_DIR/tmpl/$file", "package main; use utf8;\n$code");
    }
    closedir $dir;
}

1;
