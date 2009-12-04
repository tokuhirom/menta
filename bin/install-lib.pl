#!/usr/bin/perl
use strict;
use warnings;
use CPAN;
use File::Temp qw/tempdir tempfile/;
use File::Spec::Functions;
use FindBin;
use Cwd;
#use Data::Dumper;
use Module::CoreList;
use Getopt::Long;
use IO::Prompt;

my %installed;
my %optional_args = (
    'version'          => '--perl_only',
    'List::MoreUtils'  => '-pm',
    'Params::Validate' => '--pm',
    'DateTime'         => '--pm',
    'Params::Util'     => '-pm',
);
my %skip_packages = map { $_ => 1 } (
    'perl',           # ignore perl itself.
    'Module::Build',  # only for building
    'LWP::UserAgent', # maybe you have this.
    'HTML::Parser',   # ditto
    'HTML::Tagset',   # ditto
    'HTTP::Headers',  # ditto
    'HTTP::Response', # ditto
    'DBI',            # ditto
    'HTTP::Headers',  # ditto.
    'LWP',            # ditto.
    'WWW::MobileCarrierJP', # only for building
    'Digest::SHA1',   # たいていの場合、Digest::MD5 におきかえればインストール可能
);
my $target_version = '5.008001';
my $outdir;
my $dstdir;
my $pkg;
my $overwrite = 0;
my $force;
my $cwd = getcwd();

&main; exit;

# utils
sub Path::Class::Dir::basename { shift->dir_list(-1, 1) }

sub main {
    # process args
    GetOptions(
        "version=f" => \$target_version,
        "overwrite" => \$overwrite,
        "force=s"   => \$force,
    );
    unless (@ARGV == 2) {
        die "Usage: $0 Acme::Hello extlib/";
    }
    ($pkg, $dstdir) = @ARGV;

    # init
    my $tmpdir = tempdir(CLENAUP => 1);
    $outdir = catfile($tmpdir, "outputdir");
    mkdir -d $outdir;
    CPAN::HandleConfig->load;
    CPAN::Shell::setup_output;

    # install
    install_pkg($pkg);

    unless (%installed) {
        warn "no modules for install";
        return;
    }

    chdir $cwd;

    # copy to dst dir
    my $outlibdir = catfile($outdir, 'lib', 'perl5') . '/';
    print "sync $outlibdir => $dstdir\n";
    system qw/rsync --verbose --recursive/, $outlibdir, $dstdir;
}

sub install_pkg {
    my $pkg = shift;
    return if $installed{$pkg};
    return unless should_install($pkg);
    $installed{$pkg}++;
    local $CPAN::Config->{histfile}     = tempfile(CLEANUP => 1);
    local $CPAN::Config->{makepl_arg}   = "INSTALL_BASE=$outdir " . ($optional_args{$pkg} ? $optional_args{$pkg} : '');
    local $CPAN::Config->{mbuildpl_arg} = "--install_base=$outdir";

    print "---- installing $pkg\n";

    my $mod = CPAN::Shell->expand("Module", $pkg) or die "cannot find $pkg\n";
    my $dist = $mod->distribution;
    $dist->make;
    if (my $requires = $dist->prereq_pm) {
        for my $req (keys %{$requires->{requires}}) {
            install_pkg($req);
        }
    }
    $dist->install();
}

sub should_install {
    my $pkg = shift;

    if ($force && $force eq $pkg) {
        print "force install $pkg\n";
        return 1;
    }
    if ($Module::CoreList::version{$target_version}{$pkg}) {
        print "skip $pkg(standard lib)\n";
        return 0;
    }
    if ($skip_packages{$pkg}) {
        print "skip $pkg(build util?)\n";
        return 0;
    }
    if ($pkg =~ /^Test::/) {
        print "skip $pkg(test libs)\n";
        return 0;
    }
    unless ($overwrite) {
        my $path = $pkg;
        $path =~ s{::}{/}g;
        $path = catfile($cwd, $dstdir, "${path}.pm");
        if (-f $path) {
            print "skip $pkg(already installed)\n";
            return 0;
        }
    }
    return 1;
}
