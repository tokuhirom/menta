package MENTA::Plugin::Cache;
use strict;
use warnings;
use Cache::FileCache;

sub _cache {
    MENTA->context->plugin_stash->{cache} ||= Cache::FileCache->new();
}

sub cache_get_callback {
    my ($key, $code) = @_;
    my $c = _cache();
    $c->get($key) || do {
        my $dat = $code->();
        $c->set($key => $dat);
        $dat;
    };
}

1;
