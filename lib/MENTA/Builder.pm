package MENTA::Builder;
use strict;
use warnings;
use utf8;
use MENTA::Template;
use MENTA::Util;

my $OUTPUT_DIR = 'out';
my $SOURCE_DIR = 'app';

sub run {
    say "出力先ディレクトリを作成しています";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;

    say "メインソースをコンパイルします";
    generate_cgi();

    say "テンプレートファイルをコンパイルします";
    generate_template_files();
}

sub generate_cgi {
    say "menta.cgi をつくりあげる";
    my ($shebang,) = split /\r\n|[\r\n]/, read_file('app/menta.cgi');
    my $menta = "$shebang\n$TMPL";
    $menta .= read_file('lib/MENTA.pm');
    $menta .= read_file('app/menta.cgi');
    $menta =~ s/use MENTA;/package main;/g;
    $menta =~ s!use lib '\..\/lib';!!;
    say "menta.cgi を出力しています";
    write_file("$OUTPUT_DIR/menta.cgi" => $menta);
    my $mode = 755; #TODO
    say "chmod $mode";
    chmod oct($mode), "$OUTPUT_DIR/menta.cgi";
}

sub generate_template_files {
    mkdir "$OUTPUT_DIR/tmpl_cache/";
    opendir my $dir, "$SOURCE_DIR/tmpl" or die "テンプレートファイル用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$SOURCE_DIR/tmpl/$file";
        next unless -f $fname;
        my $src = read_file($fname);
        my $mt = MENTA::Template->new;
        $mt->parse($src);
        $mt->build();
        my $code = $mt->code();
        write_file("$OUTPUT_DIR/tmpl_cache/$file", "package main; use utf8;\n$code");
    }
    closedir $dir;
}

1;
