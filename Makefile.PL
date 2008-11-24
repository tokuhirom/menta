use inc::Module::Install;
name 'MENTA';
all_from 'lib/MENTA.pm';

license 'perl';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
use_test_base;
auto_include;
WriteAll;
