#!/bin/sh
git push --tags
sudo -u www-data rm -rf /var/www/menta/
sudo -u www-data mkdir /var/www/menta/
sudo -u www-data cp -a * /var/www/menta/
