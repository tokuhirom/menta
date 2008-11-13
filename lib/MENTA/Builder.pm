package MENTA::Builder;
use MENTA;
use MENTA::Template;

my $OUTPUT_DIR = 'out';
my $SOURCE_DIR = 'app';

{
    no strict 'refs';
    *{"MENTA::Builder::read_file"}  = *{"main::read_file"};
    *{"MENTA::Builder::write_file"} = *{"main::write_file"};
}

sub puts { print @_, "\n" };

sub run {
    puts "出力先ディレクトリを作成します";
    mkdir $OUTPUT_DIR unless -d $OUTPUT_DIR;
    my $mode = 755; #TODO
    puts "chmod $mode";
    chmod oct($mode), $OUTPUT_DIR;

    puts "メインソースをコンパイルします";
    generate_cgi();

    puts "テンプレートファイルをコンパイルします";
    generate_template_files();

    puts "静的ファイルをコピーします";
    copy_dir('static', '静的ファイル');

    puts "コントローラファイルをコピーします";
    copy_dir('controller', 'コントローラ');
}

sub generate_cgi {
    puts "menta.cgi をつくりあげる";
    my $menta = read_file('app/menta.cgi');
    my $menta_pm = read_file('lib/MENTA.pm');
    $menta =~ s/use MENTA;/use strict;use warnings;use utf8;\n$menta_pm\npackage main;/;
    $menta =~ s!use lib '\..\/lib';!!;

    puts "menta.cgi を出力します";
    write_file("$OUTPUT_DIR/menta.cgi" => $menta);
    my $mode = 755; #TODO
    puts "chmod $mode";
    chmod oct($mode), "$OUTPUT_DIR/menta.cgi";
}

sub generate_template_files {
    my $outputdir = "$OUTPUT_DIR/tmpl_cache/";
    unless (-d $outputdir) {
        mkdir $outputdir or die "キャッシュディレクトリを作成できません: $!";
    }
    opendir my $dir, "$SOURCE_DIR/tmpl" or die "テンプレートファイル用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$SOURCE_DIR/tmpl/$file";
        next unless -f $fname;
        my $src = read_file($fname);
        my $mt = MENTA::Template->new;
        $mt->parse($src);
        $mt->build();
        my $code = $mt->code();
        write_file("$outputdir/$file", "package main; use utf8;\n$code");
    }
    closedir $dir;
}

sub copy_dir {
    my ($dirname, $type) = @_;
    my $outputdir = "$OUTPUT_DIR/$dirname/";
    unless (-d $outputdir) {
        mkdir $outputdir or die "${type} 出力用ディレクトリを作成できません: $!";
    }
    opendir my $dir, "$SOURCE_DIR/$dirname/" or die "${type} 用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$SOURCE_DIR/$dirname/$file";
        next unless -f $fname;
        write_file("$outputdir/$file" => read_file($fname));
    }
    closedir $dir;
}

1;
