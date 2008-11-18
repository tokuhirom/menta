use strict;
use warnings;
use CPAN;
use File::Temp qw/tempdir tempfile/;
use File::Spec::Functions;
use FindBin;
use Cwd;
use Data::Dumper;
use Module::CoreList;
use Getopt::Long;

my %installed;
my %optional_args = (
    'version'          => '--perl_only',
    'List::MoreUtils'  => '-pm',
    'Params::Validate' => '--pm',
);
my $target_version = '5.008001';
my $outdir;

&main; exit;

# utils
sub Path::Class::Dir::basename { shift->dir_list(-1, 1) }

sub main {
    # process args
    GetOptions(
        "version=f", \$target_version,
    );
    unless (@ARGV == 2) {
        die "Usage: $0 Acme::Hello extlib/";
    }
    my ($pkg, $dstdir) = @ARGV;

    # init
    my $cwd = getcwd();
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
    system qw/rsync --verbose --recursive/,  $outlibdir, $dstdir;
}

sub install_pkg {
    my $pkg = shift;
    return if $installed{$pkg};
    $installed{$pkg}++;
    if ($Module::CoreList::version{$target_version}{$pkg}) {
        print "skip $pkg\n";
        return;
    }

    local $CPAN::Config->{histfile}   = tempfile(CLEANUP => 1);
    local $CPAN::Config->{makepl_arg} = "INSTALL_BASE=$outdir " . ($optional_args{$pkg} ? $optional_args{$pkg} : '');
    local $CPAN::Config->{mbuildpl_arg} = "--install_base=$outdir";

    my $mod = CPAN::Shell->expand("Module", $pkg) or die "cannot find $pkg";
    my $dist = $mod->distribution;
    $dist->make;
    if (my $requires = $dist->prereq_pm) {
        for my $req (keys %{$requires->{requires}}) {
            install_pkg($req);
        }
    }
    $dist->install();
}

