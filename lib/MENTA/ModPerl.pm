package MENTA::ModPerl;
use Mouse;
extends 'HTTP::Engine::Interface::ModPerl';
use MENTA;
use utf8;

sub create_engine {
    my ($class, $r, $context_key) = @_;

    # PerlSetVar MENTA_CONFIG_PATH /path/to/config.pl
    my $confpath = $r->dir_config('MENTA_CONFIG_PATH') or die "設定ファイルの場所を指定してください : PerlSetVar MENTA_CONFIG_PATH /path/to/config.pl";
    my $config = do $confpath or die "設定ファイルが変です(invalid config)";
    die "missing menta.base_dir in config" unless $config->{menta}->{base_dir};
    MENTA->add_trigger(
        BEFORE_DISPATCH => sub {
            my $r = MENTA->context->{__engine}->interface->apache;
            $ENV{PATH_INFO} = do {
                my $path_info = $ENV{REQUEST_URI};
                $path_info =~ s/@{[ $r->location ]}//;
                $path_info =~ s/\?.+//;
                $path_info;
            };
            $ENV{SCRIPT_NAME} = $r->location;
        },
    );
    MENTA->create_engine($config, 'ModPerl');
}

1;
