package MENTA::Plugin::Bundle;
use strict;
use warnings;
use UNIVERSAL::require;

my @vers = (
    'CGI::Simple'                   => '1.106',
    'Class::Accessor'               => '0.31',
    'Class::Trigger'                => '0.13',
    'Data::Page'                    => '2.01',
    'DateTime'                      => '0.45',
    'Email::MIME'                   => '1.861',
    'Email::Send'                   => '2.192',
    'HTML::FillInForm'              => '2.00',
    'HTML::StickyQuery::DoCoMoGUID' => '0.01',
    'HTML::TreeBuilder'             => '3.23',
    'HTML::TreeBuilder::XPath'      => '0.09',
    'HTTP::MobileAgent'             => '0.27',
    'HTTP::Session'                 => '0.26',
    'JSON'                          => '2.12',
    'List::MoreUtils'               => '0.22',
    'Params::Validate'              => '0.91',
    'Path::Class'                   => '0.16',
    'Scalar::Util'                  => '1.19',
    'Text::CSV'                     => '1.10',
    'Text::Hatena'                  => '0.20',
    'Text::Markdown'                => '1.0.24',
    'UNIVERSAL::require'            => '0.11',
    'URI'                           => '1.37',
    'YAML'                          => '0.66',
);

sub bundle_libs {
    @vers
}

1;
