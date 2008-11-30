# OpenID デモモジュール
use MENTA;
use Net::OpenID::Consumer::Lite;

my $OP_MAP = +{
    mixi     => 'https://mixi.jp/openid_server.pl',
    livedoor => 'https://auth.livedoor.com/openid/server',
};

sub do_openid {
    if (param('check')) {
        # OP サーバにリダイレクトする(step 2)
        my $op = param('op') or die "op の指定がないよ";
        my $server_url = $OP_MAP->{$op} or die "知らない OP だ";
        my $check_url = Net::OpenID::Consumer::Lite->check_url(
            $server_url,
            "http://$ENV{SERVER_NAME}:$ENV{SERVER_PORT}" . uri_for('demo/openid', {back => 1}),
        );
        warn $check_url;
        return redirect($check_url);
    } elsif (param('back')) {
        # OPサーバからのレスポンスを処理する(step 3)

        # 本当はよくないことだけど、SSL の証明書があってなくてもスルーしちゃう。
        local $Net::OpenID::Consumer::Lite::IGNORE_SSL_ERROR = 1;

        my $req = MENTA->context->request;
        my $params = +{ map { $_ => $req->param($_) } $req->param };
        Net::OpenID::Consumer::Lite->handle_server_response(
            $params => (
                not_openid => sub {
                    die "Not an OpenID message";
                },
                setup_required => sub {
                    my $setup_url = shift;
                    redirect($setup_url);
                },
                cancelled => sub {
                    finalize('user cancelled');
                },
                verified => sub {
                    my $vident = shift;
                    render_and_print('demo/openid_verified.mt', $vident);
                },
                error => sub {
                    my $err = shift;
                    die($err);
                },
            )
        );
    } else {
        # OP サーバをえらぶ(step 1)
        render_and_print('demo/openid_select.mt', $OP_MAP);
    }
}

