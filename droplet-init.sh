#!/bin/bash
# Script to be executed on the newly created droplet

apt-get update
apt-get upgrade -y
apt-get install -y squid

echo 'Updating default Squid configuration'
sed -i "/^acl CONNECT method CONNECT/ s/$/\nacl me src $USER_IP/" /etc/squid/squid.conf
sed -i '/^http_access allow localhost/ s/$/\nhttp_access allow me/' /etc/squid/squid.conf
sed -i 's/^# forwarded_for on/forwarded_for delete/' /etc/squid/squid.conf
sed -i 's/^# via on/via off/' /etc/squid/squid.conf
echo 'Done'

systemctl restart squid.service
systemctl --no-pager status squid.service
