package MENTA::Builder;
use MENTA;
use MENTA::Template;

{
    no strict 'refs';
    *{"MENTA::Builder::read_file"}  = *{"main::read_file"};
    *{"MENTA::Builder::write_file"} = *{"main::write_file"};
}

sub puts { print @_, "\n" };

sub run {
    my ($class, $srcdir, $outdir) = @_;

    puts "出力先ディレクトリを作成します";
    mkdir $outdir unless -d $outdir;
    my $mode = 755; #TODO
    puts "chmod $mode";
    chmod oct($mode), $outdir;

    puts "メインソースをコンパイルします";
    generate_cgi($srcdir => $outdir);

    puts "テンプレートファイルをコンパイルします";
    generate_template_files($srcdir => $outdir);

    puts "静的ファイルをコピーします";
    copy_dir($srcdir => $outdir, 'static', '静的ファイル');

    puts "コントローラファイルをコピーします";
    copy_dir($srcdir => $outdir, 'controller', 'コントローラ');
}

sub generate_cgi {
    my ($srcdir, $outdir) = @_;

    puts "menta.cgi をつくりあげる";
    my $menta = read_file("${srcdir}/menta.cgi");
    my $menta_pm = read_file('lib/MENTA.pm');
    $menta =~ s/use MENTA;/use strict;use warnings;use utf8;\n$menta_pm\npackage main;/;
    $menta =~ s!use lib '\..\/lib';!!;

    puts "menta.cgi を出力します";
    write_file("$outdir/menta.cgi" => $menta);
    my $mode = 755; #TODO
    puts "chmod $mode";
    chmod oct($mode), "$outdir/menta.cgi";
}

sub generate_template_files {
    my ($srcdir, $outdir) = @_;

    my $outputdir = "$outdir/tmpl_cache/";
    unless (-d $outputdir) {
        mkdir $outputdir or die "キャッシュディレクトリを作成できません: $!";
    }
    opendir my $dir, "$srcdir/tmpl" or die "テンプレートファイル用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$srcdir/tmpl/$file";
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
    my ($srcdir, $outdir, $dirname, $type) = @_;
    my $outputdir = "$outdir/$dirname/";
    unless (-d $outputdir) {
        mkdir $outputdir or die "${type} 出力用ディレクトリを作成できません: $!";
    }
    opendir my $dir, "$srcdir/$dirname/" or die "${type} 用ディレクトリを開けません: $!";
    while (my $file = readdir $dir) {
        my $fname = "$srcdir/$dirname/$file";
        next unless -f $fname;
        write_file("$outputdir/$file" => read_file($fname));
    }
    closedir $dir;
}

1;
