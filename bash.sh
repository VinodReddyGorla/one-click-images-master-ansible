#!/bin/bash
#
# DigitalOcean Discourse Configuration
docker ps | grep app && docker rmi --force app
clear
export UNICORN_SIDEKIQS=1

cat <<EOM
Thanks for using the DigitalOcean Discourse Application Image.
To get started, the following configuration details will be required.

- Email Address for the Discourse Admin Account
- The hostname (domain or subdomain) you will use for Discourse
- Details for the SMTP server your Discourse install will use to send email

Please press enter when you are read to configure Discourse.

This script will prompt you until _all_ values are populated.

EOM

# Make sure the user is ready to configure Discourse
read wait

# Get some input
while  [ -z "${email}" -o -z "${domain}" -o -z "${smtp}" -o -z "${smtp_port}" -o -z "${smtp_pass}" ]; do
read -p "Enter the email address to use for the Discourse admin account (ex. user@example.org) " email
read -p "Enter the domain or subdomain pointed to this Discourse instance (ex. forum.example.org): " domain
read -p "Enter the SMTP server to use to send email (ex: smtp.example.org): " smtp
read -p "SMTP Port (default 587):" smtp_port
read -p "SMTP Username (ex. user@example.org): " smtp_user
read -s -p "SMTP Password: " smtp_pass
[ -z "$smtp_port" ] && smtp_port="587"
echo ""

done

cat <<EOM

Thanks!  Your Discourse instance is now being configured....this can take a few minutes...

If you need to re-run this script, run:
   bash $(readlink -f ${0})

EOM

# Remove this file from the reference page
cp -a /etc/skel/.bashrc /root/.bashrc

# Replace seed values with correct ones
cd /var/discourse;
sed -e "s/sammy@do.co/$email/" \
    -e "s/discourse.do.co/$domain/" \
    -e "s/smtp.do.co/$smtp/" \
    -e "s/#DISCOURSE_SMTP_PORT: 587/DISCOURSE_SMTP_PORT: $smtp_port/" \
    -e "s/#DISCOURSE_SMTP_USER_NAME: user@example.com/DISCOURSE_SMTP_USER_NAME: $smtp_user/" \
    -e "s/#DISCOURSE_SMTP_PASSWORD: pa\$\$word/DISCOURSE_SMTP_PASSWORD: $smtp_pass/" \
    -i  /var/discourse/containers/app.yml

# Remove the landing page
(rm -rf /var/www/html
systemctl stop lighttpd
apt-get -qqy purge lighttpd

systemctl enable docker
systemctl start docker ) >> /dev/null

# Start up the application
bash launcher start app
did=`docker ps -q`
docker exec $did rails r "SiteSetting.notification_email = noreply@$domain'"

cat <<EOM

Now you will be prompted to set your admin password. When prompted put
'$email' as for the admin

EOM

docker exec -t -i $did rake admin:create

cat <<EOM

Discourse has now been configured. You may now finish setting up Discourse
by creating an account at:
    http://$(hostname -I |awk '{print$1}')

EOM
