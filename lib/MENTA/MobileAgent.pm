package MENTA::MobileAgent;
use strict;
use warnings;

use constant {
    NonMobile => 0,
    DoCoMo    => 1,
    SoftBank  => 2,
    EZweb     => 3,
    AirHPhone => 4,
};

# this matching should be robust enough
# detailed analysis is done in subclass's parse()
my $DoCoMoRE = '^DoCoMo/\d\.\d[ /]';
my $JPhoneRE = '^(?i:J-PHONE/\d\.\d)';
my $VodafoneRE = '^Vodafone/\d\.\d';
my $VodafoneMotRE = '^MOT-';
my $SoftBankRE = '^SoftBank/\d\.\d';
my $SoftBankCrawlerRE = '^Nokia[^/]+/\d\.\d';
my $EZwebRE  = '^(?:KDDI-[A-Z]+\d+[A-Z]? )?UP\.Browser\/';
my $AirHRE = '^Mozilla/3\.0\((?:WILLCOM|DDIPOCKET)\;';
our $MobileAgentRE = qr/(?:($DoCoMoRE)|($JPhoneRE|$VodafoneRE|$VodafoneMotRE|$SoftBankRE|$SoftBankCrawlerRE)|($EZwebRE)|($AirHRE))/;

sub detect {
    my($class, $ua) = @_;

    my $sub = NonMobile;
    if ($ua =~ $MobileAgentRE) {
        $sub = $1 ? DoCoMo : $2 ? SoftBank : $3 ? EZweb : AirHPhone;
    }
    return $sub;
}


# HTTP::MobileAgent::Plugin::Charset よりポート。
# cp932 の方が実績があるので優先させる方針。
# Shift_JIS とかじゃなくて cp932 にしとかないと、諸問題にひっかかりがちなので注意
sub detect_charset {
    my ($class, $ua) = @_;
    my $type = $class->detect($ua);
    return 'utf-8' if $type eq NonMobile;
    return 'utf-8' if $type eq DoCoMo   && $ua =~ m{^DoCoMo/2\.0 (?!(?:D210i|SO210i)|503i|211i|SH251i|692i|200[12]|2101V)};
    return 'utf-8' if $type eq SoftBank && $ua =~ /^(?:Vodafone|SoftBank|MOT-)/;
    return 'cp932';
}

1;
