package MENTA::Builder;
use strict;
use warnings;
use utf8;
use MENTA::Template;
use MENTA::Util;

my $OUTPUT_DIR = 'out';
my $SOURCE_DIR = 'app';

my $TMPL = <<'...';
### SHEBANG ###
use strict;
use warnings;
use utf8;

### INCLUDE 'lib/MENTA.pm' ###
### INCLUDE 'app/menta.cgi' ###
...

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
        $fname =~ s!^\.\./*!!;
        _read_and_indent($fname, 2);
    }ge;
    $src;
}

sub _read_and_indent {
    my ($fname, $indent_level) = @_;
    my $one_level = 4;
    my $indent = ' ' x ($indent_level*$one_level);
    "{\n" . join("\n", grep { /^\s*$/ or $_ = $indent . $_; 1 }
                       split("\n", read_file($fname)))
          . "\n" . (' ' x (($indent_level-1)*$one_level)) . "}\n";
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
    say "menta.cgi をつくりあげる";
    my $menta = $TMPL;
    $menta = replace($menta, {
        SHEBANG => do {
            my ($shebang,) = split /\r\n|[\r\n]/, read_file('app/menta.cgi');
            $shebang;
        },
    });
    $menta =~ s/use MENTA;/package main;/g;
    $menta =~ s/use lib 'lib';//;
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
