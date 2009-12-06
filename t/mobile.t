use Test::More tests => 8;
use t::Utils;
use Encode;
use utf8;

{
    my @map = (
        'DoCoMo/2.0 P01B(c500;TB;W24H15)'    => 'DoCoMo' => 'utf-8',
        'DoCoMo/1.0/N211i/c10'               => 'DoCoMo' => 'cp932',
        'UP.Browser/3.04-TS13 UP.Link/3.4.4' => 'EZweb' => 'cp932',
        'Vodafone/1.0/941SH/SHJ001 Browser/NetFront/3.5 Profile/MIDP-2.0 Configuration/CLDC-1.1' => 'Vodafone' => 'utf-8',
        'MOT-C980/80.2F.2E. MIB/2.2.1 Profile/MIDP-2.0 Configuration/CLDC-1.1' => 'Vodafone' => 'utf-8',
        'Vodafone/1.0/V804N/NJ001 Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1' => 'Vodafone' => 'utf-8',
        'J-PHONE/3.0/V304T'                  => 'Vodafone' => 'cp932',
        'non-mobile'                         => 'NonMobile' => 'utf-8',
    );
    while (my ($ua, $carrier, $encoding) = splice @map, 0, 3) {
        my $out = run_cgi(
            PATH_INFO      => '/demo/mobile',
            HTTP_USER_AGENT => $ua,
        );
        like decode($encoding, $out), qr/あなたのブラウザは $carrier/;
    }
}

