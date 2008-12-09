package MENTA::Plugin::OpenID;
use MENTA::Plugin;
use Net::OpenID::Consumer::Lite;
use Encode ();

my $OP_MAP = {
    mixi     => {
        endpoint => 'https://mixi.jp/openid_server.pl',
        nickname_fetcher => sub {
            my $vident = shift;
            Encode::decode_utf8($vident->{'sreg.nickname'});
        }
    },
    livedoor => {
        endpoint => 'https://auth.livedoor.com/openid/server',
        nickname_fetcher => sub {
            my $vident = shift;
            my $identity = $vident->{identity} or die "identity がない？";
            if ($identity =~ m{^http://profile\.livedoor\.com/([^/]+)/$}) {
                return $1;
            } else {
                die "不正なOpenID? : $identity";
            }
        }
    }
};
my $ENDPOINT2NICKFETCHER = +{ map { $_->{endpoint} => $_->{nickname_fetcher} } values %$OP_MAP };

sub openid_get_user {
    if (my $user = MENTA::session_get('plugin.openid.user')) {
        return $user;
    } else {
        return undef;
    }
}

sub openid_login_url_map {
    my %args_in = @_;

    my $args = {};
    for my $key (qw/cancelled verified/) {
        $args->{$key} = delete $args_in{$key} or die "openid_make_login_url に $key が渡されていません";
    }
    MENTA::session_set('plugin.openid._id_res' => $args);

    my $res;
    for my $name (keys %$OP_MAP) {
        $res->{$name} = MENTA::uri_for('plugin/openid/check_url', { op => $name });
    }
    $res;
}

sub do_check_url {
    my $op         = MENTA::param('op')    or die "op の指定がないよ";
    my $server_url = $OP_MAP->{$op}->{endpoint} or die "知らない OP だ";
    my $check_url = Net::OpenID::Consumer::Lite->check_url(
        $server_url,
        "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}" . MENTA::uri_for( 'plugin/openid/id_res', { back => 1, ret_url => MENTA::param('ret_url') } ),
        {
            "http://openid.net/extensions/sreg/1.1" => { required => join( ",", qw/email nickname/ ) }
        }
    );
    return MENTA::redirect($check_url);
}

sub do_id_res {
    my $req = MENTA->context->request;
    my $params = +{ map { $_ => $req->param($_) } $req->param };
    my $option = MENTA::session_get('plugin.openid._id_res');
    my $cadir = $ENV{HTTPS_CA_DIR};
    local $ENV{HTTPS_CA_DIR};
    if ($cadir) {
        $ENV{HTTPS_CA_DIR} = $cadir;
    } elsif (-d '/etc/ssl/certs') {
        $ENV{HTTPS_CA_DIR} = '/etc/ssl/certs';
    }
    Net::OpenID::Consumer::Lite->handle_server_response(
        $params => (
            not_openid => sub {
                die "Not an OpenID message";
            },
            setup_required => sub {
                my $setup_url = shift;
                MENTA::redirect($setup_url);
            },
            cancelled => sub {
                MENTA::redirect($option->{cancelled});
            },
            verified => sub {
                my $vident = shift;
                my $identity = $vident->{identity};
                my $id = {
                    nickname => $ENDPOINT2NICKFETCHER->{$vident->{op_endpoint}}->( $vident ),
                    openid   => $identity,
                };
                MENTA::session_set('plugin.openid.user' => $id);
                MENTA::redirect($option->{verified});
            },
            error => sub {
                die "認証エラーです。SSL 通信に失敗しました: $@";
            },
        )
    );
}

1;
