#pi debian 11 install Librenms
#20220815 改PHP8.1

echo input mysql librenms db password
read lmpw
echo input default community string
read cms

#get ip
sudo apt install -y -q net-tools git
ip=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
#安裝相關套件
echo "安裝相關套件"
apt install apt-transport-https lsb-release ca-certificates wget -y
wget -O /etc/apt/trusted.gpg.d/php.gpg https://packages.sury.org/php/apt.gpg
echo "deb https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/sury-php.list
apt update -y
apt install acl curl fping git graphviz imagemagick mariadb-client mariadb-server mtr-tiny nginx-full nmap php-cli php-curl php-fpm php-gd php-gmp php-json php-mbstring php-mysql php-snmp php-xml php-zip python3-dotenv python3-pymysql python3-redis python3-setuptools python3-systemd python3-pip rrdtool snmp snmpd whois -y

#新增使用者
echo "新增使用者"
useradd librenms -d /opt/librenms -M -r -s "$(which bash)"

#下載LibreNMS
echo "下載LibreNMS"
cd /opt
git clone https://github.com/librenms/librenms.git

#設定權限
echo "設定權限"
chown -R librenms:librenms /opt/librenms
chmod 771 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

#設定PHP依賴
echo "設定PHP依賴"
#sudo -u librenms php /opt/librenms/scripts/composer_wrapper.php install --no-dev
cd /opt/librenms
su - librenms -c "yes | ./scripts/composer_wrapper.php install --no-dev"

#設定資料庫(這邊注意要修改密碼，預設為KH_password)
echo "設定資料庫"
systemctl restart mysql
mysql -uroot <<EOF
	CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
	CREATE USER 'librenms'@'localhost' IDENTIFIED BY '$lmpw';
	GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
	FLUSH PRIVILEGES;
	exit
EOF

> /etc/mysql/mariadb.conf.d/50-server.cnf
echo [server] >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo [mysqld] >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo innodb_file_per_table=1 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo sql-mode=\"\" >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo lower_case_table_names=0 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo user            = mysql >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo pid-file        = /var/run/mysqld/mysqld.pid >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo socket          = /var/run/mysqld/mysqld.sock >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo port            = 3306 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo basedir         = /usr >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo datadir         = /var/lib/mysql >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo tmpdir          = /tmp >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo lc-messages-dir = /usr/share/mysql >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo skip-external-locking >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo bind-address            = 127.0.0.1 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo key_buffer_size         = 16M >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo max_allowed_packet      = 16M >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo thread_stack            = 192K >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo thread_cache_size       = 8 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo myisam-recover         = BACKUP >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo query_cache_limit       = 1M >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo query_cache_size        = 16M >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo log_error = /var/log/mysql/error.log >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo expire_logs_days        = 10 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo max_binlog_size   = 100M >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo character-set-server  = utf8mb4 >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo collation-server      = utf8mb4_general_ci >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo [embedded] >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo [mariadb] >> /etc/mysql/mariadb.conf.d/50-server.cnf
echo [mariadb-10.0] >> /etc/mysql/mariadb.conf.d/50-server.cnf
systemctl restart mysql


#設定Web Server
echo date.timezone = \"Asia/Taipei\" >> /etc/php/8.1/fpm/php.ini
echo date.timezone = \"Asia/Taipei\" >> /etc/php/8.1/cli/php.ini
phpenmod mcrypt

#這個不加會有驗證錯誤
timedatectl set-timezone Asia/Taipei

#設定PHP-FPM
#cp /etc/php/7.4/fpm/pool.d/www.conf /etc/php/7.4/fpm/pool.d/librenms.conf
cp /etc/php/8.1/fpm/pool.d/www.conf /etc/php/8.1/fpm/pool.d/librenms.conf
sed -i 's/\[www\]/\[librenms\]/g' /etc/php/8.1/fpm/pool.d/librenms.conf
sed -i 's/user \= www-data/user = librenms/g' /etc/php/8.1/fpm/pool.d/librenms.conf
sed -i 's/group \= www-data/group = librenms/g' /etc/php/8.1/fpm/pool.d/librenms.conf
sed -i 's/php\/php8.1-fpm.sock/php-fpm-librenms.sock/g' /etc/php/8.1/fpm/pool.d/librenms.conf
sed -i 's/listen.group \= librenms/listen.group = www-data/g' /etc/php/8.1/fpm/pool.d/librenms.conf


#設定NGINX
echo		server {	 >> /etc/nginx/conf.d/librenms.conf
echo		 listen      80\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 server_name $ip\; 	 >> /etc/nginx/conf.d/librenms.conf
echo		 root        \/opt\/librenms\/html\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 index       index.php\;	 >> /etc/nginx/conf.d/librenms.conf
echo			 >> /etc/nginx/conf.d/librenms.conf
echo		 charset utf-8\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 gzip on\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 gzip_types text\/css application\/javascript text\/javascript application\/x-javascript image\/svg+xml text\/plain text\/xsd text\/xsl text\/xml image\/x-icon\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 location \/ {	 >> /etc/nginx/conf.d/librenms.conf
echo		  try_files \$uri \$uri\/ \/index.php?\$query_string\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 }	 >> /etc/nginx/conf.d/librenms.conf
echo		 location \/api\/v0 {	 >> /etc/nginx/conf.d/librenms.conf
echo		  try_files \$uri \$uri\/ \/api_v0.php?\$query_string\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 }	 >> /etc/nginx/conf.d/librenms.conf
echo		 location \~ \\.php {	 >> /etc/nginx/conf.d/librenms.conf
echo		  include fastcgi.conf\;	 >> /etc/nginx/conf.d/librenms.conf
echo		  fastcgi_split_path_info \^\(.+\\.php\)\(\/.+\)\$\;	 >> /etc/nginx/conf.d/librenms.conf
echo		  fastcgi_pass unix:\/var\/run\/php-fpm-librenms.sock\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 }	 >> /etc/nginx/conf.d/librenms.conf
echo		 location \~ \/\\.ht {	 >> /etc/nginx/conf.d/librenms.conf
echo		  deny all\;	 >> /etc/nginx/conf.d/librenms.conf
echo		 }	 >> /etc/nginx/conf.d/librenms.conf
echo		}	 >> /etc/nginx/conf.d/librenms.conf
rm /etc/nginx/sites-enabled/default
systemctl reload nginx
systemctl restart php8.1-fpm

#Enable lnms
ln -s /opt/librenms/lnms /usr/bin/lnms
cp /opt/librenms/misc/lnms-completion.bash /etc/bash_completion.d/

#配置snmpd
cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf
#sed -e 's/RANDOMSTRINGGOESHERE/public/' -i /etc/snmp/snmpd.conf
sed -i "2s/RANDOMSTRINGGOESHERE/${cms}/g" /etc/snmp/snmpd.conf
curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
chmod +x /usr/bin/distro
systemctl restart snmpd
#加入排程
cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
#轉出 logs 目錄下的記錄檔
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

#設定LibreNMS
#chown -R librenms:librenms /opt/librenms
#setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
#setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
#cd /opt/librenms
#./scripts/composer_wrapper.php install --no-dev
#chown -R librenms:librenms /opt/librenms
#setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
#setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/


#clear
echo "安裝完成"
echo "請開啟網址: http://"$ip"/install.php"
