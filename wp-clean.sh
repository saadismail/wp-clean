#!/bin/bash
# Bash script written by Saad Ismail - saadismail.net

#Copyright (C) 2015 Saad Ismail
#This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# Usage: ./wp.sh $USERNAME or sh wp.sh $USERNAME (where $USERNAME is cPanel's USERNAME which you want to be cleaned)

dir="/home/$1/public_html"

if [[ ! $1 ]]; then
        echo "I need the username, run it as ./wp.sh USERNAME"
        exit 1
fi

if [[ ! -e $dir/wp-config.php ]]; then
        echo "Can't find wordpress installed in ${dir}"
        exit 1
fi

cd $dir
touch /tmp/infectwp/log/$1.txt
plugins_before=$( ls ${dir}/wp-content/plugins | wc -l )

mv wp-config.php /home/$1/tmp/
mv wp-content /home/$1/tmp/
rm -rf $dir/*
wget -q https://wordpress.org/latest.zip
unzip -q latest.zip
rm -rf ${dir}/wordpress/wp-content
cd ${dir}
mv ${dir}/wordpress/* ${dir}/
mv /home/$1/tmp/wp-config.php $dir/
mv /home/$1/tmp/wp-content $dir/
cd ${dir}/wp-content
mv index.php index.php.bak
rm -f *.php *.txt 12421_input__12.php. 12421_input__12.php5
mv index.php.bak index.php
cd ${dir}/wp-content/plugins

for plugin in *; do
        # Check if we already have that plugin
        if [[ -e /tmp/infectwp/plugins/${plugin}.zip ]]; then
                echo "${plugin} already exist, copying from that dir" >> /tmp/infectwp/log/$1.txt
        else
                cd /tmp/infectwp/plugins/
                wget -q https://downloads.wordpress.org/plugin/${plugin}.zip
        fi

        if [[ -e /tmp/infectwp/plugins/${plugin}.zip ]]; then
                cp /tmp/infectwp/plugins/${plugin}.zip ${dir}/wp-content/plugins/
                cd ${dir}/wp-content/plugins/
                rm -rf ${dir}/wp-content/plugins/${plugin}
                unzip -q ${dir}/wp-content/plugins/${plugin}.zip
                rm -f ${dir}/wp-content/plugins/${plugin}.zip
        else
                echo "${plugin} failed"
                echo "${plugin} didn't Removed" >> /tmp/infectwp/log/$1.txt
        fi
done

plugins_after=$( ls ${dir}/wp-content/plugins | wc -l )
if [[ $plugins_before -eq $plugins_after ]]; then
        echo "You did a great job"
else
        echo "Plugins Before: ${plugins_before}"
        echo "Plugins After: ${plugins_after}"
fi

rm -f ${dir}/latest.zip
rm -rf ${dir}/wordpress
find ${dir}/wp-content/uploads -name '*.php'

chown -R ${1}:${1} ${dir}
chown ${1}:nobody ${dir}

cd $dir
db_name=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
db_user=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
db_pass=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`

mysql -D${db_name} -u${db_user} -p${db_pass} << "EOF"
SELECT * FROM wp_users;
EOF

echo "Which ID?"
read id

newwppass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 18)

mysql -D${db_name} -u${db_user} -p${db_pass} -e "UPDATE wp_users SET user_pass= MD5('${newwppass}') WHERE ID = ${id}"

mysql -D${db_name} -u${db_user} -p${db_pass} << "EOF"
SELECT *
FROM  `wp_options`
WHERE  `option_name` LIKE  'template';
EOF

echo "This assumed that wp prefix is wp & isn't changed"
echo "In case you got an error, you should check theme manually in ${db_name}"

echo "Go to /home/$1/public_html/wp-content/themes to make sure that no un-necessary theme exist there"

echo "Username: admin"
echo "Password: ${newwppass}"

echo "Do you also want me to remove all themes & download a fresh one?"
echo "1 for yes, 0 for no"
read themeconfirm

if [[ $themeconfirm == "1" ]]; then
	echo "Let me know the direct link to theme which is currently configured"
	read themelink
	filename=$(basename "$themelink")
	if [[ ! $themelink ]]; then
			echo "Couldn't find theme link, exiting"
			exit
	fi
	cd /home/$1/public_html/wp-content/themes
	mv index.php .index.php
	rm -rf *
	wget $themelink
	echo "Is it tar on zip? tar for tar.gz, zip for .zip"
	read tarorzip
	if [[ $tarorzip == "tar" ]]; then
			tar zxvf $filename
	elif [[ $tarorzip == "zip" ]]; then
			unzip $filename
	fi
fi
