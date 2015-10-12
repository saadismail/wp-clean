#!/bin/bash
# Bash script written by Saad Ismail - me@saadismail.net

# Copyright (C) 2015 Saad Ismail
# This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.

# Usage: ./wp.sh $USERNAME or sh wp.sh $USERNAME (where $USERNAME is cPanel's USERNAME which you want to be cleaned)

# Directory path where wordpress is installed
dir="/home/$1/public_html"

# A temporary directory to put wp-content & wp-config.php
tmpdir="/home/$1/tmp"

# Making sure that you gave an argument 
if [[ ! $1 ]]; then
        echo "I need the username, run it as ./wp.sh USERNAME"
        exit 1
fi

# Making sure that wordpress is installed on that directory
if [[ ! -e $dir/wp-config.php ]]; then
        echo "Can't find wordpress installed in ${dir}"
        exit 1
fi

# Creating directories & files needed
mkdir -p /tmp/infectwp/log/
mkdir -p /tmp/infectwp/plugins/
touch /tmp/infectwp/log/${1}.txt
if [[ ! -e $tmpdir ]]; then
	mkdir $tmpdir
fi

# Counting installed plugins in $dir/wp-content/plugins before cleaning
check=$( ls ${dir}/wp-content/plugins | wc -l )
# Subtracting index.php existing under $dir/wp-content/plugins
plugins_before=`expr ${check} - 1`

# Wordpress core part starts from here
mv ${dir}/wp-config.php ${tmpdir}/
mv ${dir}/wp-content ${tmpdir}/
# It deletes all of the sub-directories & files under given directory
rm -rf ${dir}/*
wget -q https://wordpress.org/latest.zip -P ${tmpdir}
mv ${tmpdir}/latest.zip ${dir}/latest.zip
unzip -q ${dir}/latest.zip -d ${dir}
rm -rf ${dir}/wordpress/wp-content
mv ${dir}/wordpress/* ${dir}/
mv ${tmpdir}/wp-config.php $dir/
mv ${tmpdir}/wp-content $dir/
mv ${dir}/wp-content/index.php ${tmpdir}/wp-content-index.php
# Removing a set of files under $dir/wp-content/, add your own if needed
rm -f *.php *.txt 12421_input__12.php. 12421_input__12.php5

mv ${tmpdir}/wp-content-index.php ${dir}/wp-content/index.php
rm -f ${dir}/latest.zip
rm -rf ${dir}/wordpress
# Wordpress core part ends here

# Wordpress plugin part starts from here
cd ${dir}/wp-content/plugins
for plugin in *; do
        # Check if we already have that plugin
        if [[ -e /tmp/infectwp/plugins/${plugin}.zip ]]; then
                echo "${plugin} already exist, copying from that dir" >> /tmp/infectwp/log/$1.txt
        else
                cd /tmp/infectwp/plugins/
				# Otherwise try to download it from wordpress repo
                wget -q https://downloads.wordpress.org/plugin/${plugin}.zip
        fi

		# Making sure that we've that plugin now
        if [[ -e /tmp/infectwp/plugins/${plugin}.zip ]]; then
                cp /tmp/infectwp/plugins/${plugin}.zip ${dir}/wp-content/plugins/
                cd ${dir}/wp-content/plugins/
                rm -rf ${dir}/wp-content/plugins/${plugin}
                unzip -q ${dir}/wp-content/plugins/${plugin}.zip
                rm -f ${dir}/wp-content/plugins/${plugin}.zip
        else
		# If can't find that plugin on wordpress.org (Plugin is no longer there or is paid one)
                echo "${plugin} failed"
				echo "${plugin} failed" >> /tmp/infectwp/log/$1.txt
                echo "${plugin} didn't Removed" >> /tmp/infectwp/log/$1.txt
        fi
done

# Counting installed plugins in $dir/wp-content/plugins after cleaning
check=$( ls ${dir}/wp-content/plugins | wc -l )
# Subtracting index.php existing under $dir/wp-content/plugins
plugins_after=`expr ${check} - 1`

# Checking if count of plugins before & after doesn't matches
if [[ ! $plugins_before -eq $plugins_after ]]; then
        echo "Plugins Before: ${plugins_before}"
        echo "Plugins After: ${plugins_after}"
fi

# Wordpress plugin part ends here

# Notifying if there are any php files under ${dir}/wp-content/uploads
echo "Notifying if there are any php files under ${dir}/wp-content/uploads"
find ${dir}/wp-content/uploads -name '*.php'

# Wordpress Database part starts from here
cd ${dir}

# Getting values from wp-config.php file
db_name=`cat wp-config.php | grep DB_NAME | cut -d \' -f 4`
db_user=`cat wp-config.php | grep DB_USER | cut -d \' -f 4`
db_pass=`cat wp-config.php | grep DB_PASSWORD | cut -d \' -f 4`
db_prefix=$(cat wp-config.php | grep "\$table_prefix" | cut -d \' -f 2)

# Showing all usernames to make sure that I don't reset password of wrong user
mysql -D${db_name} -u${db_user} -p${db_pass} << "EOF"
SELECT * FROM wp_users;
EOF

# Asking ID of user whose password you want to reset
echo "Which ID?"
read id

# Generating random password
newwppass=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 18)

# Updating wordpress username's password
mysql -D${db_name} -u${db_user} -p${db_pass} -e "UPDATE wp_users SET user_pass= MD5('${newwppass}') WHERE ID = ${id}"

# Showing the theme which is in use at the moment
echo "Note current theme name listed here under option_value"
mysql -D${db_name} -u${db_user} -p${db_pass} -e "SELECT * FROM ${db_prefix}options WHERE option_name LIKE 'template';"
# Database part ends here

# Setting permissions according to cPanel's standard
chown -R ${1}:${1} ${dir}
chown ${1}:nobody ${dir}

# Giving new password
echo "New Password: ${newwppass}"
echo "New Password: ${newwppass}" >> /tmp/infectwp/log/$1.txt

# Wordpress theme part starts here
mkdir -p /tmp/infectwp/themes
echo "Do you also want me to remove all themes & download a fresh one?"
echo "1 for yes, 0 for no"
read themeconfirm

if [[ $themeconfirm == "1" ]]; then
	echo "Let me know the direct link to theme which is currently configured"
	read themelink
	
	# Making sure that you gave a theme link
	if [[ ! $themelink ]]; then
					echo "Couldn't find theme link, exiting"
					exit
	fi
	
	# Extracting filename from link
	filename=$(basename "$themelink")
	cd /home/$1/public_html/wp-content/themes
	# Downloading that theme
	wget -q $themelink -P /tmp/infectwp/themes
	# Making sure that I got a theme archive
	if [[ -e /tmp/infectwp/themes/$filename ]]; then
		mv /home/$1/public_html/wp-content/themes/index.php ${tmpdir}/wp-themes-index.php
		rm -rf /home/$1/public_html/wp-content/themes/*
		mv /tmp/infectwp/themes/$filename /home/$1/public_html/wp-content/themes/$filename
		# Checking what extension archive has
		if [[ $filename == *.zip ]]; then
			unzip -q $filename -d /home/$1/public_html/wp-content/themes/
		elif [[ $filename == *.tar ]]; then
			tar xf $filename -C /home/$1/public_html/wp-content/themes/
		elif [[ $filename == *.tar.gz ]]; then
			tar zxf $filename -C /home/$1/public_html/wp-content/themes/
		else
			echo "Theme isn't in zip/tar/tar.gz form"
		fi
		rm -f /home/$1/public_html/wp-content/themes/$filename
		mv ${tmpdir}/wp-themes-index.php /home/$1/public_html/wp-content/themes/index.php
	else
		echo "Couldn't download from ${themelink}"
		echo "Couldn't download from ${themelink}" >> /tmp/infectwp/log/$1.txt
	fi
	# Setting permissions according to cPanel's standard
	chown -R ${1}:${1} ${dir}
	chown ${1}:nobody ${dir}
fi

