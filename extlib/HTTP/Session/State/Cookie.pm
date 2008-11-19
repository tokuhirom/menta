package HTTP::Session::State::Cookie;
use HTTP::Session::State::Base;
use CGI::Cookie;
use Carp ();

__PACKAGE__->mk_ro_accessors(qw/name path domain expires/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # set default values
    $args{name} ||= 'http_session_sid';
    $args{path} ||= '/';
    bless {%args}, $class;
}

sub get_session_id {
    my ($self, $req) = @_;

    my %jar    = CGI::Cookie->parse($ENV{HTTP_COOKIE} || $req->header('Cookie'));
    my $cookie = $jar{$self->name};
    return $cookie ? $cookie->value : undef;
}

sub response_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    $self->header_filter($session_id, $res);
}

sub header_filter {
    my ($self, $session_id, $res) = @_;
    Carp::croak "missing session_id" unless $session_id;

    my $cookie = CGI::Cookie->new(
        sub {
            my %options = (
                -name   => $self->name,
                -value  => $session_id,
                -path   => $self->path,
            );
            $options{'-domain'} = $self->domain if $self->domain;
            $options{'-expires'} = $self->expires if $self->expires;
            %options;
        }->()
    );
    $res->header( 'Set-Cookie' => $cookie->as_string );
}

1;
__END__

=head1 NAME

HTTP::Session::State::Cookie - Maintain session IDs using cookies

=head1 SYNOPSIS

    HTTP::Session->new(
        state => HTTP::Session::State::Cookie->new(
            name   => 'foo_sid',
            path   => '/my/',
            domain => 'example.com,
        ),
        store => ...,
        request => ...,
    );

=head1 DESCRIPTION

Maintain session IDs using cookies

=head1 CONFIGURATION

=over 4

=item name

cookie name.

    default: http_session_sid

=item path

path.

    default: /

=item domain

    default: undef

=item expires

expire date.e.g. "+3M".
see also L<CGI::Simple::Cookie>.

    default: undef

=back

=head1 METHODS

=over 4

=item header_filter($res)

header filter

=item get_session_id

=item response_filter

for internal use only

=back

=head1 SEE ALSO

L<HTTP::Session>

