use inc::Module::Install;
name 'MENTA';
all_from 'lib/MENTA.pm';

license 'perl';
test_requires 'Test::Requires';

tests 't/*.t t/*/*.t t/*/*/*.t t/*/*/*/*.t';
use_test_base;
auto_include;
WriteAll;
