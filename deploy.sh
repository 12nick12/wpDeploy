#!/bin/bash
# Type of instance Base 19.2

# wpDeploy
# Nick Leffler
# 20190930 v1

##### EDIT HERE ####
#siteName="_"
#siteTitle="TEST"
#adminEmail="test@test.com"
#siteURL="test.url.com"
#siteProto="http://"

wwwUser="nginx"
#### DON"T TOUCH BELOW HERE ####

get_info () {
read -p "Enter Site Name: " siteName
read -p "Enter Site Title: " siteTitle
read -p "If SSL type ssl otherwise don't: " siteProtoIn
read -p "Enter Site URL: " siteURL
read -p "Enter WPAdmin email: " adminEmail

if [[ $siteProtoIn == "ssl" ]]; then
	siteProto="https://"
	ssl=1
fi

fullURL="${siteProto}${siteURL}"
}

genSSL () {
mkdir -p "/etc/nginx/ssl/${siteURL}/" || exit
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/nginx/ssl/${siteURL}/key -out /etc/nginx/ssl/${siteURL}/crt \
    -subj "/C=TT/ST=TT/L=TT/O=TEMP/OU=TEMP/CN=$siteURL/emailAddress=TEMP"
}

create_wp_db () {
siteNoP=$(echo "${siteURL}" | sed 's/\.//g')
# create wordpress user with passwd
wpasswd=$(openssl rand 39 -base64 | cut -c1-37)
wpapasswd=$(openssl rand 39 -base64 | cut -c1-37)
mysql -e "create database ${siteNoP}"
mysql -e "grant all on ${siteNoP}.* to ${siteNoP}@localhost identified by '${wpasswd}'"
}

vHostHTTP () {
siteFile="/etc/nginx/sites-available/${siteURL}"
# create nginx config for site
cat <<EOF > "${siteFile}"
server {
        ## Your website name goes here.
        server_name "${siteURL}";
        ## Your only path reference.
        root "${siteFP}";
        ## This should be in your http block and if it is, it's not needed here.
        index index.php;

     location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~ /\. {
        access_log off;
        log_not_found off;
        deny all;
    }

    location ~* \\.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }


    location / {
        # This is cool because no php is touched for static content.
        # include the "?\$args" part so non-default permalinks doesn't break when using query string
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Pass PHP scripts to PHP-FPM
    location ~* \\.php\$ {
        fastcgi_index   index.php;
        fastcgi_intercept_errors on;
        fastcgi_pass    php;
        #fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
        include         fastcgi_params;
        fastcgi_param   SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
        fastcgi_param   SCRIPT_NAME        \$fastcgi_script_name;
    }
}
EOF
}

vHostHTTPS () {
# create nginx config for site
siteFile="/etc/nginx/sites-available/${siteURL}"
cat <<EOF > "${siteFile}"
server {
    listen 80;
    server_name "${siteURL}";
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl;
        ## Your website name goes here.
        server_name "${siteURL}";
        ## Your only path reference.
        root "${siteFP}";
        ## This should be in your http block and if it is, it's not needed here.
        index index.php;

     location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }

    location ~ /\. {
        access_log off;
        log_not_found off;
        deny all;
    }

    location ~* \\.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }


    location / {
        # This is cool because no php is touched for static content.
        # include the "?\$args" part so non-default permalinks doesn't break when using query string
        try_files \$uri \$uri/ /index.php?\$args;
    }

    # Pass PHP scripts to PHP-FPM
    location ~* \\.php\$ {
        fastcgi_index   index.php;
        fastcgi_intercept_errors on;
        fastcgi_pass    php;
        #fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
        include         fastcgi_params;
        fastcgi_param   SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
        fastcgi_param   SCRIPT_NAME        \$fastcgi_script_name;
    }
	ssl on;
    ssl_certificate /etc/nginx/ssl/${siteURL}/crt;
    ssl_certificate_key /etc/nginx/ssl/${siteURL}/key;

    ssl_ciphers "ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-DSS-AES128-GCM-SHA256:kEDH+AESGCM:ECDHE-RSA-AES128-SHA256:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA:ECDHE-ECDSA-AES256-SHA:DHE-RSA-AES128-SHA256:DHE-RSA-AES128-SHA:DHE-DSS-AES128-SHA256:DHE-RSA-AES256-SHA256:DHE-DSS-AES256-SHA:DHE-RSA-AES256-SHA:!aNULL:!eNULL:!EXPORT:!DES:!RC4:!3DES:!MD5:!PSK";
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
    add_header X-Content-Type-Options nosniff;
    ssl_stapling on;
    ssl_stapling_verify on;
    resolver 8.8.8.8 4.2.2.1 valid=300s;
    resolver_timeout 5s;
}
EOF
}

nginx-conf () {
if [[ "${ssl}" = 1 ]]; then
	vHostHTTPS
	genSSL
else
	vHostHTTP
fi
}

########################################################################
#                                                                      #
#                           Starts HERE                                #
#                                                                      #
########################################################################

# set defaults
siteProto="http://"
ssl=0

# get mdata
get_info

# Create variable from inputed ones
siteFP="/usr/share/nginx/html/${siteURL}/wordpress"

# do mysql stuff
create_wp_db

# create admin email 
#adminEmail="admin@${siteURL}"

# Create site with wp-cli
mkdir -p "${siteFP}" || exit
cd "${siteFP}" || exit
chown -R "${wwwUser}":"${wwwUser}" "$(dirname ${siteFP})"
sudo -u "${wwwUser}" /usr/local/bin/wp core download
sudo -u "${wwwUser}" /usr/local/bin/wp config create --dbname="${siteNoP}" --dbuser="${siteNoP}" --dbpass="${wpasswd}" --path="${siteFP}"
sudo -u "${wwwUser}" /usr/local/bin/wp core install --url="${siteURL}" --title="${siteTitle}" --admin_user="wpm258159" --admin_password="${wpapasswd}" --admin_email="${adminEmail}" --path="${siteFP}" --skip-email


# Confiugre nginx and create config
nginx-conf
ln -s ${siteFile} /etc/nginx/sites-enabled/
nginx -t
read -p "Would you like to reload nginx to take new changes?: [y/n]" yy
if [ $yy == "y" ]; then 
  echo "reloading nginx"
  systemctl reload nginx
fi

# Echo errythang that matters
echo "The WP sql password is: ${wpasswd}"
echo "${siteName} is at ${siteProto}${siteURL} with the title ${siteTitle} and the admin email of ${adminEmail}"
echo "The wp-admin email/username is: ${adminEmail} and the password is: ${wpapasswd}"
echo "Thank you and have a great day"
