package MENTA::CGI;
use strict;
use warnings;
use CGI::Simple ();

no warnings 'redefine';
sub CGI::Simple::_add_param {
    my ( $self, $param, $value, $overwrite ) = @_;
    return () unless defined $param and defined $value;
    $param =~ tr/\000//d if $self->{'.globals'}->{'NO_NULL'};
    @{ $self->{$param} } = () if $overwrite;
    @{ $self->{$param} } = () unless exists $self->{$param};
    my @values = ref $value ? @{$value} : ($value);
    for my $value (@values) {
        next
          if $value eq ''
              and $self->{'.globals'}->{'NO_UNDEF_PARAMS'};
        $value =~ tr/\000//d if $self->{'.globals'}->{'NO_NULL'};
        $value = MENTA::Util::decode_input( $value ); # XXX この行だけ変えてる
        push @{ $self->{$param} }, $value;
        unless ( $self->{'.fieldnames'}->{$param} ) {
            push @{ $self->{'.parameters'} }, $param;
            $self->{'.fieldnames'}->{$param}++;
        }
    }
    return scalar @values;    # for compatibility with CGI.pm request.t
}

1;
