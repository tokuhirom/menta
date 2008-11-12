### SHEBANG ###
use strict;
use warnings;
use utf8;

### INCLUDE 'lib/MENTA.pm' ###
### INCLUDE 'lib/MENTA/Controller/Base.pm' ###
### INCLUDE 'lib/MENTA/Injector.pm' ###

MENTA::Injector->inject();

### INCLUDE 'app/index.cgi' ###

