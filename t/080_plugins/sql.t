use strict;
use warnings;
use Test::More tests => 1;
use t::Utils;

my $out_cgi = run_cgi(
    PATH_INFO      => '/demo/bbs_sqlite',
);
like $out_cgi, qr/Status: 200/;
unlike $out_cgi, qr/Error trace/;
? for my $entry (@{$entries||[]}) {
? }
#     <li class="hentry"><?= $entry->{id} ?> <?= $entry->{body} ?> by <a href="<?= $entry->{openid} ?>"><?= $entry->{nickname} ?></a></li>
# ?= render('pager.mt', $pager, 'demo/bbs_sqlite')
