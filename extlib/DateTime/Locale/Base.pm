package DateTime::Locale::Base;

use strict;
use warnings;

use Class::ISA;
use DateTime::Locale;
use List::MoreUtils ();
use Params::Validate qw( validate_pos );

BEGIN
{
    foreach my $field ( qw( id en_complete_name native_complete_name
                            en_language en_script en_territory en_variant
                            native_language native_script native_territory native_variant
                          )
                      )
    {
        # remove leading 'en_' for method name
        (my $meth_name = $field) =~ s/^en_//;

        # also remove 'complete_'
        $meth_name =~ s/complete_//;

        no strict 'refs';
        *{$meth_name} = sub { $_[0]->{$field} };
    }
}

sub new
{
    my $class = shift;

    # By making the default format lengths part of the object's hash
    # key, it allows them to be settable.
    return bless { @_,
                   default_date_format_length => $class->_default_date_format_length(),
                   default_time_format_length => $class->_default_time_format_length(),
                 }, $class;
}

sub language_id  { ( DateTime::Locale::_parse_id( $_[0]->id ) )[0] }
sub script_id    { ( DateTime::Locale::_parse_id( $_[0]->id ) )[1] }
sub territory_id { ( DateTime::Locale::_parse_id( $_[0]->id ) )[2] }
sub variant_id   { ( DateTime::Locale::_parse_id( $_[0]->id ) )[3] }

my @FormatLengths = qw( short medium long full );

sub date_format_default
{
    my $meth = 'date_format_' . $_[0]->default_date_format_length();
    $_[0]->$meth();
}

sub date_formats
{
    return
        { map { my $meth = 'date_format_' . $_;
                $_ => $_[0]->$meth() } @FormatLengths }
}

sub time_format_default
{
    my $meth = 'time_format_' . $_[0]->default_time_format_length();
    $_[0]->$meth();
}

sub time_formats
{
    return
        { map { my $meth = 'time_format_' . $_;
                $_ => $_[0]->$meth() } @FormatLengths }
}

sub format_for
{
    my $self = shift;
    my $for  = shift;

    my $meth = '_format_for_' . $for;

    return unless $self->can($meth);

    return $self->$meth();
}

sub available_formats
{
    my $self = shift;

    # The various parens seem to be necessary to force uniq() to see
    # the caller's list context. Go figure.
    my @uniq = List::MoreUtils::uniq( map { keys %{ $_->_available_formats() || {} } }
                                      Class::ISA::self_and_super_path( ref $self ) );

    # Doing the sort in the same expression doesn't work under 5.6.x.
    return sort @uniq;
}

# Just needed for the above method.
sub _available_formats { }

sub default_date_format_length { $_[0]->{default_date_format_length} }

sub set_default_date_format_length
{
    my $self = shift;
    my ($l) = validate_pos( @_, { regex => qr/^(?:full|long|medium|short)$/i } );

    $self->{default_date_format_length} = lc $l;
}

sub default_time_format_length { $_[0]->{default_time_format_length} }

sub set_default_time_format_length
{
    my $self = shift;
    my ($l) = validate_pos( @_, { regex => qr/^(?:full|long|medium|short)/i } );

    $self->{default_time_format_length} = lc $l;
}

for my $length ( qw( full long medium short ) )
{
    my $key = 'datetime_format_' . $length;

    my $sub =
        sub { my $self = shift;

              return $self->{$key} if exists $self->{$key};

              my $date_meth = 'date_format_' . $length;
              my $time_meth = 'time_format_' . $length;

              return $self->{$key} = $self->_make_datetime_format( $date_meth, $time_meth );
            };

    no strict 'refs';
    *{$key} = $sub;
}

sub datetime_format_default
{
    my $self = shift;

    my $date_meth = 'date_format_' . $self->default_date_format_length();
    my $time_meth = 'time_format_' . $self->default_time_format_length();

    return $self->_make_datetime_format( $date_meth, $time_meth );
}

sub _make_datetime_format
{
    my $self      = shift;
    my $date_meth = shift;
    my $time_meth = shift;

    my $dt_format = $self->datetime_format();

    my $time = $self->$time_meth();
    my $date = $self->$date_meth();

    $dt_format =~ s/\{0\}/$time/g;
    $dt_format =~ s/\{1\}/$date/g;

    return $dt_format;
}

sub prefers_24_hour_time
{
    my $self = shift;

    return $self->{prefers_24_hour_time}
        if exists $self->{prefers_24_hour_time};

    $self->{prefers_24_hour_time} =
        $self->time_format_short() =~ /h|K/ ? 0 : 1;
}

# Backwards compat for DateTime.pm version <= 0.42
sub month_name          { $_[0]->month_format_wide()->       [ $_[1]->month_0 ] }
sub month_abbreviation  { $_[0]->month_format_abbreviated()->[ $_[1]->month_0 ] }
sub month_narrow        { $_[0]->month_format_narrow()->     [ $_[1]->month_0 ] }

sub month_names         { $_[0]->month_format_wide() }
sub month_abbreviations { $_[0]->month_format_abbreviated() }
sub month_narrows       { $_[0]->month_format_narrow() }

sub day_name            { $_[0]->day_format_wide()->       [ $_[1]->day_of_week_0 ] }
sub day_abbreviation    { $_[0]->day_format_abbreviated()->[ $_[1]->day_of_week_0 ] }
sub day_narrow          { $_[0]->day_format_narrow()->     [ $_[1]->day_of_week_0 ] }

sub day_names           { $_[0]->day_format_wide() }
sub day_abbreviations   { $_[0]->day_format_abbreviated() }
sub day_narrows         { $_[0]->day_format_narrow() }

sub quarter_name         { $_[0]->quarter_format_wide()->       [ $_[1]->quarter - 1 ] }
sub quarter_abbreviation { $_[0]->quarter_format_abbreviated()->[ $_[1]->quarter - 1 ] }
sub quarter_narrow       { $_[0]->quarter_format_narrow()->     [ $_[1]->quarter - 1 ] }

sub quarter_names         { $_[0]->quarter_format_wide() }
sub quarter_abbreviations { $_[0]->quarter_format_abbreviated() }

sub am_pm { $_[0]->am_pm_abbreviated()->[ $_[1]->hour < 12 ? 0 : 1 ] }
sub am_pms { $_[0]->am_pm_abbreviated() }

sub era_name         { $_[0]->era_wide()->       [ $_[1]->ce_year < 0 ? 0 : 1 ] }
sub era_abbreviation { $_[0]->era_abbreviated()->[ $_[1]->ce_year < 0 ? 0 : 1 ] }
sub era_narrow       { $_[0]->era_narrow()->     [ $_[1]->ce_year < 0 ? 0 : 1 ] }

sub era_names         { $_[0]->era_wide() }
sub era_abbreviations { $_[0]->era_abbreviated() }

# ancient backwards compat
sub era  { $_[0]->era_abbreviation }
sub eras { $_[0]->era_abbreviations }

sub date_before_time
{
    my $self = shift;

    my $dt_format = $self->datetime_format();

    return $dt_format =~ /\{1\}.*\{0\}/ ? 1 : 0;
}

sub date_parts_order
{
    my $self = shift;

    my $short = $self->date_format_short();

    $short =~ tr{dmyDMY}{}cd;
    $short =~ tr{dmyDMY}{dmydmy}s;

    return $short;
}

sub full_date_format   { $_[0]->_convert_to_strftime( $_[0]->date_format_full() ) }
sub long_date_format   { $_[0]->_convert_to_strftime( $_[0]->date_format_long() ) }
sub medium_date_format { $_[0]->_convert_to_strftime( $_[0]->date_format_medium() ) }
sub short_date_format  { $_[0]->_convert_to_strftime( $_[0]->date_format_short() ) }
sub default_date_format { $_[0]->_convert_to_strftime( $_[0]->date_format_default() ) }

sub full_time_format   { $_[0]->_convert_to_strftime( $_[0]->time_format_full() ) }
sub long_time_format   { $_[0]->_convert_to_strftime( $_[0]->time_format_long() ) }
sub medium_time_format { $_[0]->_convert_to_strftime( $_[0]->time_format_medium() ) }
sub short_time_format  { $_[0]->_convert_to_strftime( $_[0]->time_format_short() ) }
sub default_time_format { $_[0]->_convert_to_strftime( $_[0]->time_format_default() ) }

sub full_datetime_format   { $_[0]->_convert_to_strftime( $_[0]->datetime_format_full() ) }
sub long_datetime_format   { $_[0]->_convert_to_strftime( $_[0]->datetime_format_long() ) }
sub medium_datetime_format { $_[0]->_convert_to_strftime( $_[0]->datetime_format_medium() ) }
sub short_datetime_format  { $_[0]->_convert_to_strftime( $_[0]->datetime_format_short() ) }
sub default_datetime_format { $_[0]->_convert_to_strftime( $_[0]->datetime_format_default() ) }

# Older versions of DateTime.pm will not pass in the $cldr_ok flag, so
# we will give them the converted-to-strftime pattern (bugs and all).
sub _convert_to_strftime
{
    my $self    = shift;
    my $pattern = shift;
    my $cldr_ok = shift;

    return $pattern if $cldr_ok;

    return $self->{_converted_patterns}{$pattern}
        if exists $self->{_converted_patterns}{$pattern};

    return $self->{_converted_patterns}{$pattern} = $self->_cldr_to_strftime($pattern);
}

{
    my @JavaPatterns =
        ( qr/G/     => '{era}',
          qr/yyyy/  => '{ce_year}',
          qr/y/     => 'y',
          qr/u/     => 'Y',
          qr/MMMM/  => 'B',
          qr/MMM/   => 'b',
          qr/MM/    => 'm',
          qr/M/     => '{month}',
          qr/dd/    => 'd',
          qr/d/     => '{day}',
          qr/hh/    => 'l',
          qr/h/     => '{hour_12}',
          qr/HH/    => 'H',
          qr/H/     => '{hour}',
          qr/mm/    => 'M',
          qr/m/     => '{minute}',
          qr/ss/    => 'S',
          qr/s/     => '{second}',
          qr/S/     => 'N',
          qr/EEEE/  => 'A',
          qr/E/     => 'a',
          qr/D/     => 'j',
          qr/F/     => '{weekday_of_month}',
          qr/w/     => 'V',
          qr/W/     => '{week_month}',
          qr/a/     => 'p',
          qr/k/     => '{hour_1}',
          qr/K/     => '{hour_12_0}',
          qr/z/     => '{time_zone_long_name}',
        );

    sub _cldr_to_strftime
    {
        shift;
        my $simple = shift;

        $simple =~
            s/(G+|y+|u+|M+|d+|h+|H+|m+|s+|S+|E+|D+|F+|w+|W+|a+|k+|K+|z+)|'((?:[^']|'')*)'/
                $2 ? _stringify($2) : $1 ? _convert($1) : "'"/eg;

        return $simple;
    }

    sub _convert
    {
        my $simple = shift;

        for ( my $x = 0; $x < @JavaPatterns; $x += 2 )
        {
            return '%' . $JavaPatterns[ $x + 1 ] if $simple =~ /$JavaPatterns[$x]/;
        }

        die "**Dont know $simple***";
    }

    sub _stringify
    {
        my $string = shift;

        $string =~ s/%(?:[^%])/%%/g;
        $string =~ s/\'\'/\'/g;

        return $string;
    }
}

# end backwards compat

sub STORABLE_freeze
{
    my $self = shift;
    my $cloning = shift;

    return if $cloning;

    return $self->id();
}

sub STORABLE_thaw
{
    my $self = shift;
    my $cloning = shift;
    my $serialized = shift;

    my $obj = DateTime::Locale->load( $serialized );

    %$self = %$obj;

    return $self;
}


1;

__END__

=head1 NAME

DateTime::Locale::Base - Base class for individual locale objects

=head1 SYNOPSIS

  use base 'DateTime::Locale::Base';

=head1 DEFAULT FORMATS

Each locale has a set of four default date and time formats.  They are
distinguished by length, and are called "full", "long", "medium", and
"short". Each locale may have a different default length which it uses
when its C<< $locale->date_format_default() >>, C<<
$locale->time_format_default() >>, or C<<
$locale->datetime_format_default() >> methods are called.

This can be changed by calling the C<<
$locale->set_default_date_format() >> or C<<
$locale->set_default_time_format() >> methods.  These methods accept a
string which must be one of "full", "long", "medium", or "short".

=head1 NAME FORMS

Most names come in a number of variations. First, they may vary based
on length, with wide, abbreviated, and narrow forms. The wide form is
typically the full name, while the narrow form is often a single
character. The narrow forms may not be unique. For example, "T" may be
used for Tuesday and Thursday in the English narrow forms.

Many names also distinguish between "format" and "stand-alone" forms
of a pattern. The format pattern is used when the thing in question is
being placed into a larger string. The stand-alone form is used when
displaying that item by itself, for example in a calendar.

=head1 METHODS

All locales provide the following methods:

=over 4

=item * $locale->id()

The locale's id.

=item * $locale->language_id()

The language portion of the id.

=item * $locale->script_id()

The script portion of the id, if any.

=item * $locale->territory_id()

The territory portion of the id, if any.

=item * $locale->variant_id()

The variant portion of the id, if any.

=item * $locale->name()

The full name for the locale in English.

=item * $locale->language()

The language name for the locale in English.

=item * $locale->script()

The script name for the locale in English, if any.

=item * $locale->territory()

The territory name for the locale in English, if any.

=item * $locale->variant()

The variant name for the locale in English, if any.

=item * $locale->native_name()

The full name for the locale in its native language, if any.

=item * $locale->native_language()

The language name for the locale in its native language, if any.

=item * $locale->native_script()

The script name for the locale in its native language, if any.

=item * $locale->native_territory()

The territory name for the locale in its native language, if any.

=item * $locale->native_variant()

The variant name for the locale in its native language, if any.

=item * $locale->month_format_wide()

Returns an array reference containing the wide format names of the
months, with January as the first month.

=item * $locale->month_format_abbreviated()

Returns an array reference containing the abbreviated format names of
the months, with January as the first month.

=item * $locale->month_format_narrow()

Returns an array reference containing the narrow format names of the
months, with January as the first month.

=item * $locale->month_stand_alone_wide()

Returns an array reference containing the wide stand-alone names of
the months, with January as the first month.

=item * $locale->month_stand_alone_abbreviated()

Returns an array reference containing the abbreviated stand-alone
names of the months, with January as the first month.

=item * $locale->month_stand_alone_narrow()

Returns an array reference containing the narrow stand-alone names of the
months, with January as the first month.

=item * $locale->day_format_wide()

Returns an array reference containing the wide format names of the
days, with Monday as the first day.

=item * $locale->day_format_abbreviated()

Returns an array reference containing the abbreviated format names of
the days, with Monday as the first day.

=item * $locale->day_format_narrow()

Returns an array reference containing the narrow format names of the
days, with Monday as the first day.

=item * $locale->day_stand_alone_wide()

Returns an array reference containing the wide stand-alone names of
the days, with Monday as the first day.

=item * $locale->day_stand_alone_abbreviated()

Returns an array reference containing the abbreviated stand-alone
names of the days, with Monday as the first day.

=item * $locale->day_stand_alone_narrow()

Returns an array reference containing the narrow stand-alone names of
the days, with Monday as the first day.

=item * $locale->quarter_format_wide()

Returns an array reference containing the wide format names of the
quarters.

=item * $locale->quarter_format_abbreviated()

Returns an array reference containing the abbreviated format names of
the quarters.

=item * $locale->quarter_format_narrow()

Returns an array reference containing the narrow format names of the
quarters.

=item * $locale->quarter_stand_alone_wide()

Returns an array reference containing the wide stand-alone names of
the quarters.

=item * $locale->quarter_stand_alone_abbreviated()

Returns an array reference containing the abbreviated stand-alone
names of the quarters.

=item * $locale->quarter_stand_alone_narrow()

Returns an array reference containing the narrow stand-alone names of the
quarters.

=item * $locale->era_wide()

Returns an array reference containing the wide names of the eras, with
"BCE" first.

=item * $locale->era_abbreviated()

Returns an array reference containing the abbreviated names of the
eras, with "BCE" first.

=item * $locale->era_narrow()

Returns an array reference containing the abbreviated names of the
eras, with "BCE" first. However, most locales do not differ between
the narrow and abbreviated length of the era.

=item * $locale->am_pm_abbreviated()

Returns an array reference containing the abbreviated names of "AM"
and "PM".

=item * $locale->date_format_long()

=item * $locale->date_format_full()

=item * $locale->date_format_medium()

=item * $locale->date_format_short()

Returns the CLDR date pattern of the appropriate length.

=item * $locale->date_formats()

Returns a hash reference of CLDR date patterns for the date formats,
where the keys are "full", "long", "medium", and "short".

=item * $locale->time_format_long()

=item * $locale->time_format_full()

=item * $locale->time_format_medium()

=item * $locale->time_format_short()

Returns the CLDR date pattern of the appropriate length.

=item * $locale->time_formats()

Returns a hash reference of CLDR date patterns for the time formats,
where the keys are "full", "long", "medium", and "short".

=item * $locale->datetime_format_long()

=item * $locale->datetime_format_full()

=item * $locale->datetime_format_medium()

=item * $locale->datetime_format_short()

Returns the CLDR date pattern of the appropriate length.

=item * $locale->datetime_formats()

Returns a hash reference of CLDR date patterns for the datetime
formats, where the keys are "full", "long", "medium", and "short".

=item * $locale->date_format_default()

=item * $locale->time_format_default()

=item * $locale->datetime_format_default()

Returns the default CLDR date pattern. The length of this format is
based on the value of C<< $locale->default_date_format_length() >>
and/or C<< $locale->default_time_format_length() >>.

=item * $locale->default_date_format_length()

=item * $locale->default_time_format_length()

Returns the default length for the format, one of "full", "long",
"medium", or "short".

=item * $locale->set_default_date_format_length()

=item * $locale->set_default_time_format_length()

Sets the default length for the format. This must be one of "full",
"long", "medium", or "short".

=item * $locale->prefers_24_hour_time()

Returns a boolean indicating the preferred hour format for this
locale.

=item * $locale->first_day_of_week()

Returns a number from 1 to 7 indicating the I<local> first day of the
week. For example, for a US locale this returns 7.

=item * $locale->available_formats()

A list of format names, like "MMdd" or "yyyyMM". This should be the
list directly supported by the subclass, not its parents.

=item * $locale->format_for($key)

Given a valid name, returns the CLDR date pattern for that thing, if
one exists.

=back

=head1 SUPPORT

See L<DateTime::Locale>.

=head1 AUTHORS

Richard Evans <rich@ridas.com>

Dave Rolsky <autarch@urth.org>

=head1 COPYRIGHT

Copyright (c) 2003 Richard Evans. Copyright (c) 2004-2005 David
Rolsky. All rights reserved. This program is free software; you can
redistribute it and/or modify it under the same terms as Perl itself.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=cut
