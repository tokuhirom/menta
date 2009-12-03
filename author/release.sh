#!/bin/zsh
shipit
git push --tags
make dist
github-upload MENTA-`perl -Ilib -Icgi-extlib-perl/extlib/ -MMENTA -e 'print $MENTA::VERSION'`.tar.gz tokuhirom/menta
