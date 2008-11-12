package MENTA::Builder;
use strict;
use warnings;
use utf8;
use MENTA::Template;
use MENTA::Util;

my $OUTPUT_DIR = 'out';
my $SOURCE_DIR = 'app';

sub replace {
    my ($src, $params) = @_;
    $src =~ s{###\s+INCLUDE\s+'([^']+)'\s+###}{
        read_source($1);
    }gem;
    while (my ($key, $val) = each %$params) {
        $src =~ s/### $key ###/$val/g;
    }
    $src;
}

sub read_source {
    my $fname = shift;
    my $src = _read_and_indent($fname, 1);
    $src =~ s{require\s+['"]([^'"]+)['"]\s*;}{
        my $fname = $1;
        _read_and_indent($1, 2);
    }ge;
    $src;
}

sub _read_and_indent {
    my ($fname, $indent_level) = @_;
    my $one_level = 4;
    my $indent = ' ' x ($indent_level*$one_level);
    "{\n$indent" . join("\n$indent", split("\n", read_file($fname))) . "\n" . (' ' x (($indent_level-1)*$one_level)) . "}\n";
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
            my ($shebang,) = split /\r\n|[\r\n]/, read_file('app/index.cgi');
            $shebang;
        },
    });
    $menta =~ s/use MENTA::Base;/package main;/g;
    $menta =~ s/use lib 'lib';//;
    say "index.cgi を出力しています";
    write_file("$OUTPUT_DIR/index.cgi" => $menta);
    my $mode = 755; #TODO
    say "chmod $mode";
    chmod oct($mode), "$OUTPUT_DIR/index.cgi";
}

sub generate_template_files {
    mkdir "$OUTPUT_DIR/tmpl";
    opendir my $dir, "$SOURCE_DIR/tmpl" or die "テンプレートファイル用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$SOURCE_DIR/tmpl/$file";
        next unless -f $fname;
        my $src = read_file($fname);
        my $mt = MENTA:Template->new;
        utf8::decode($src) unless utf8::is_utf8($src);
        $mt->parse($src);
        $mt->build();
        my $code = $mt->code();
        utf8::encode($code);
        write_file("$OUTPUT_DIR/tmpl/$file", "package main; use utf8;\n$code");
    }
    closedir $dir;
}

1;
