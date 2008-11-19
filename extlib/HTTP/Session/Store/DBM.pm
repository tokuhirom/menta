package HTTP::Session::Store::DBM;
use strict;
use warnings;
use base qw/Class::Accessor::Fast/;
use Fcntl;
use Storable;
use UNIVERSAL::require;

__PACKAGE__->mk_ro_accessors(qw/file dbm_class/);

sub new {
    my $class = shift;
    my %args = ref($_[0]) ? %{$_[0]} : @_;
    # check required parameters
    for (qw/file/) {
        Carp::croak "missing parameter $_" unless $args{$_};
    }
    # set default values
    $args{dbm_class} ||= 'SDBM_File';
    bless {%args}, $class;
}

sub dbm {
    my $self = shift;
    $self->{dbm} ||= do {
        my %hash;
        $self->dbm_class->use or die $@;
        tie %hash, $self->dbm_class, $self->file, O_CREAT | O_RDWR, oct("600");
        \%hash;
    };
}

sub select {
    my ( $self, $key ) = @_;
    Storable::thaw $self->dbm->{$key};
}

sub insert {
    my ( $self, $key, $value ) = @_;
    $self->dbm->{$key} = Storable::freeze $value;
}
sub update { shift->insert(@_) }

sub delete {
    my ( $self, $key ) = @_;
    delete $self->dbm->{$key};
}

1;
