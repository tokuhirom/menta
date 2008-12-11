#!/bin/sh
sudo -u www-data rm -rf /var/www/menta/
sudo -u www-data mkdir /var/www/menta/
sudo -u www-data cp -a * /var/www/menta/
sudo /etc/init.d/apache2 restart
