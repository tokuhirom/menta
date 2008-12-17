package Data::Page::Navigation;

use strict;
use warnings;
use Data::Page;
our $VERSION='0.03';

package Data::Page;

__PACKAGE__->mk_accessors(qw/pages_per_navigation/);

sub pages_in_navigation(){
    my $self = shift;

    my $last_page = $self->last_page;
    my $pages_per_navigation = shift || $self->pages_per_navigation || 10;
    return ($self->first_page..$last_page) if $pages_per_navigation >= $last_page;

    my $prev = $self->current_page - 1;
    my $next = $self->current_page + 1;
    my @ret = ($self->current_page);
    my $i=0;
    while(@ret < $pages_per_navigation){
        if($i%2){
            unshift(@ret,$prev) if $self->first_page <= $prev;
            --$prev;
        }else{
            push(@ret,$next) if $last_page >= $next;
            $next++;
        }
        $i++;
    }
    return @ret;
}

sub first_navigation_page {
    my $self = shift;
    my @pages = $self->pages_in_navigation;
    shift @pages;
}

sub last_navigation_page {
    my $self = shift;
    my @pages = $self->pages_in_navigation;
    pop @pages;
}

1;


__END__

=head1 NAME

Data::Page::Navigation - adds methods for page navigation to Data::Page

=head1 SYNOPSIS

    use Data::Page::Navigation;
    my $total_entries=180;
    my $entries_per_page = 10;
    my $pages_per_navigation = 10;
    my $current_page = 1;

    my $pager = Data::Page->new(
        $total_entries,
        $entries_per_page,
        $current_page
    );
    $pager->pages_per_navigation($pages_per_navigation);
    @list = $pager->pages_in_navigation($pages_per_navigation);
    #@list = qw/1 2 3 4 5 6 7 8 9 10/;

    $pager->current_page(9);
    @list = $pager->pages_in_navigation($pages_per_navigation);
    #@list = qw/5 6 7 8 9 10 11 12 13 14/;

=head1 DESCRIPTION

Using this module instead of, or in addition to Data::Page, adds a few methods to Data::Page.

This modules allow you to get the array where page numbers of the number that you set are included.
The array is made so that a current page may come to the center as much as possible in the array. 

=head1 METHODS

=head2 pages_per_navigation

Setting the number of page numbers displayed on one page. default is 10

=head2 pages_in_navigation([pages_per_navigation])

This method returns an array where page numbers of the number that you set with pages_per_navigation are included

=head2 first_navigation_page

Returns the first page in the list returned by pages_in_navigation().

=head2 last_navigation_page

Returns the last page in the list returned by pages_in_navigation().

=head1 SEE ALSO

L<Data::Page>

=head1 AUTHOR

Masahiro Nagano, E<lt>kazeburo@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2005 by Masahiro Nagano

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.5 or,
at your option, any later version of Perl 5 you may have available.


=cut
