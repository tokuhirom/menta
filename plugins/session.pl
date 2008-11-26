package MENTA::Plugin::Session;
use MENTA::Plugin;
use HTTP::Session;
use HTTP::Session::Store::DBM;

sub _postrun {
    my ($app, $bodyref) = @_;
    $app->session->header_filter($app);
}

my $hooked;

sub _create_state {
    my $klass = main::mobile_agent->is_non_mobile ? 'HTTP::Session::State::Cookie' : 'HTTP::Session::State::URI';
    $HTTP::Session::State::Cookie::COOKIE_CLASS = 'CGI::Simple::Cookie';
    (my $path = $klass) =~ s!::!/!og;
    $path .= '.pm';
    MENTA::Util::require_once $path;
    $klass->new();
}

sub _session {
    $MENTA::STASH->{'plugin::session'} ||= sub {
        my $session = HTTP::Session->new(
            store   => HTTP::Session::Store::DBM->new(
                file => join('/', main::data_dir, 'session.dbm'),
            ),
            state   => _create_state(),
            request => MENTA->context->request(),
            id      => 'HTTP::Session::ID::MD5',
        );
        unless ($hooked++) {
            MENTA->add_trigger('BEFORE_OUTPUT' => sub {
                $session->response_filter(MENTA->context->res);
                $session->finalize;
            });
        }
        $session;
    }->();
}

sub session_state_class { ref _session->state() }
sub session_store_class { ref _session->store() }

{
    no strict 'refs';
    my $pkg = __PACKAGE__;
    for my $meth (qw/get set keys remove as_hashref expire regenerate_session_id session_id/) {
        *{"${pkg}::session_${meth}"} = sub {
            _session()->$meth(@_);
        };
    }
}

1;
