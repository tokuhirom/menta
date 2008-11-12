### SHEBANG ###
use strict;
use warnings;
use utf8;

### MAIN ###

### CONTROLLER_BASE ###

{
    no strict 'refs';
    *{"main::redirect"} = *{"MENTA::Controller::Base::redirect"};
    *{"main::render"}   = *{"MENTA::Controller::Base::render"};
}

### CONTROLLER ###

