package MENTA::Builder;
use MENTA;
use MENTA::Template;

my $OUTPUT_DIR = 'out';
my $SOURCE_DIR = 'app';

{
    no strict 'refs';
    *{"MENTA::Builder::read_file"} = *{"main::read_file"};
    *{"MENTA::Builder::write_file"} = *{"main::write_file"};
}

sub puts { print @_, "\n" };

sub run {
    puts "出力先ディレクトリを作成しています";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;

    puts "メインソースをコンパイルします";
    generate_cgi();

    puts "テンプレートファイルをコンパイルします";
    generate_template_files();
}

sub generate_cgi {
    puts "menta.cgi をつくりあげる";
    my ($shebang,) = split /\r\n|[\r\n]/, read_file('app/menta.cgi');
    my $menta = join( "\n",
        $shebang,
        "use strict;use warnings;use utf8;",
        read_file('lib/MENTA.pm'),
        read_file('app/menta.cgi'),
    );
    $menta =~ s/use MENTA;/package main;/g;
    $menta =~ s!use lib '\..\/lib';!!;
    puts "menta.cgi を出力しています";
    write_file("$OUTPUT_DIR/menta.cgi" => $menta);
    my $mode = 755; #TODO
    puts "chmod $mode";
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
