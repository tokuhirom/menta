package Hatena::API::Auth;
use strict;
use warnings;
our $VERSION = 0.05;

use base qw (Class::Accessor::Fast Class::ErrorHandler);

use URI;
use LWP::UserAgent;
use Digest::MD5 qw(md5_hex);

BEGIN {
    use Carp;
    our $HAVE_JSON_SYCK;
    eval { require JSON::Syck; $HAVE_JSON_SYCK = 1 };
    eval { require JSON } unless $HAVE_JSON_SYCK;
    Carp::croak("JSON::Syck or JSON required to use " . __PACKAGE__) if $@;
    *_parse_json =
        $HAVE_JSON_SYCK  ? sub { JSON::Syck::Load($_[1]) }
                         : sub { JSON::jsonToObj($_[1])  };
}

__PACKAGE__->mk_accessors(qw(api_key secret));

sub uri_to_login {
    my $self = shift;
    my %parameters = ref $_[0] eq 'HASH' ? %{$_[0]} : @_;
    my $uri = URI->new('http://auth.hatena.ne.jp/auth');
    my $request = {
        api_key => $self->api_key,
        %parameters,
    };
    $uri->query_form(
        %$request,
        api_sig => $self->api_sig($request),
    );
    return $uri;
}

sub api_sig {
    my $self = shift;
    my $args = shift;
    my $sig = $self->secret;
    for my $key (sort {$a cmp $b} keys %{$args}) {
        my $value = $args->{$key} ? $args->{$key} : '';
        $sig .= $key . $value;
    }
    return Digest::MD5::md5_hex($sig);
}

sub ua {
    my $self = shift;
    if (@_) {
        $self->{_ua} = shift;
    } else {
        $self->{_ua} and return $self->{_ua};
        $self->{_ua} = LWP::UserAgent->new;
        $self->{_ua}->agent(join '/', __PACKAGE__, __PACKAGE__->VERSION);
    }
    $self->{_ua};
}

sub _get_auth_as_json {
    my $self = shift;
    my $cert = shift or croak "You must specify your cert as an argument.";
    my $uri = URI->new('http://auth.hatena.ne.jp/api/auth.json');
    my $request = {
        api_key => $self->api_key,
        cert    => $cert,
    };
    $uri->query_form(
        %$request,
        api_sig => $self->api_sig($request),
    );
    my $res = $self->ua->get($uri->as_string);
    $res->is_success ? $res->content : $self->error($res->status_line);
}

sub login {
    my $self = shift;
    my $cert = shift or croak "Invalid argumet (no cert)";
    my $auth = $self->_get_auth_as_json($cert)
        or return $self->error($self->errstr);
    my $json = $self->_parse_json($auth);
    if ($json->{has_error}) {
        return $self->error($json->{error}->{message});
    } else {
        return Hatena::API::Auth::User->new($json->{user});
    }
}

package Hatena::API::Auth::User;
use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(name image_url thumbnail_url));

1;

__END__

=head1 NAME

Hatena::API::Auth - Perl intaface to the Hatena Authentication API

=head1 VERSION

Version 0.04

=head1 SYNOPSIS

    use Hatena::API::Auth;

    my $api = Hatena::API::Auth->new({
        api_key => '...',
        secret  => '...',
    });

    my $uri = $api->uri_to_login;
    print $uri->as_string;

    my $cert = $q->param('cert');
    my $user = $api->login($cert) or die "Couldn't login: " . $api->errstr;
    $user->name;
    $user->image_url;
    $user->thumbnail_url;

=head1 DESCRIPTION

A simple interface for using the Hatena Authentication API
L<http://auth.hatena.ne.jp/>.

=head1 METHODS

=over 4

=item new({ api_key => '...', secret => '...' })

Returns an instance of Hatena::API::Auth. It requires two parameters,
"api_key" and "secret" which can be retrieved from the Web site of
Hatena Authentication API (L<http://auth.hatena.ne.jp/>).

=item uri_to_login(%extra)

Returns a URI object which is associated with the login url and
required parameters. You can also use this method in your templates of
L<Template> like this:

  <a href="[% api.uri_to_login %]">login</a>

C<uri_to_login> takes extra URI parameters as arguments like this:

  <a href="[% api.uri_to_login(foo => 'bar', bar => 'baz') %]">login</a>

Then extracted URI will have extra URI parameters such as
C<foo=bar&bar=baz>. Those parameters will be passed to the
Authentication API. They will be returned to your application as query
parameters of the callback URL.

=item login($cert)

Logs into Hatena with a Web API and returns a Hatena::API::Auth::User
object which knows some information of the logged user. It requires
"cert", which can be retrieved from the web site, as an argument.

The user object has some accessor for user's information.

=over 4

=item name()

Returns an account name on Hatena.

=item image_url()

Returns a url of a user's profile image.

=item thumbnail_url()

Returns a url of a thumbnail of user's profile image.

=back

=item api_sig($request)

An internal method for generating signatures.

=item ua

Set/Get HTTP a user-agent for custormizing its behaviour.

=back

=head1 AUTHOR

Naoya Ito, C<< <naoya at bloghackers.net> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-hatena-api at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Hatena-API-Auth>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Hatena::API::Auth

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Hatena-API-Auth>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Hatena-API-Auth>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Hatena-API-Auth>

=item * Search CPAN

L<http://search.cpan.org/dist/Hatena-API-Auth>

=back

=head1 SEE ALSO

Hatena Authentication API L<http://auth.hatena.ne.jp/>
Hatena L<http://www.hatena.ne.jp/>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Naoya Ito, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.
