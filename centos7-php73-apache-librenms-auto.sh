#Centos 7 install Librenms

echo input mysql librenms db password
read lmpw
echo input default community string
read cms

yum install -y epel-release git net-tools

ip=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`

yum install -y composer cronie fping git httpd ImageMagick jwhois mariadb mariadb-server mtr MySQL-python net-snmp net-snmp-utils nmap python-memcached rrdtool python3 python3-pip zip unzip gcc python3-devel

yum localinstall -y http://rpms.remirepo.net/enterprise/remi-release-7.rpm
yum install -y yum-utils yum-config-manager
yum-config-manager --enable remi-php73
yum-config-manager --disable remi-php54 remi-php55 remi-php56 remi-php70 remi-php71 remi-php72 remi-test
yum install -y cronie fping git ImageMagick jwhois mtr MySQL-python net-snmp net-snmp-utils nmap mod_php php-fpm php-cli php-common php-curl php-gd php-mbstring php-process php-snmp php-xml php-zip php-memcached php-mysqlnd python-memcached rrdtool



useradd librenms -d /opt/librenms -M -r
usermod -a -G librenms apache

cd /opt
git clone https://github.com/librenms/librenms.git librenms

systemctl start mariadb
systemctl enable mariadb
mysql -u root <<EOF
        CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
        CREATE USER 'librenms'@'localhost' IDENTIFIED BY "$lmpw";
        GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
        FLUSH PRIVILEGES;
        exit
EOF

> /etc/my.cnf.d/server.cnf
echo [server] >> /etc/my.cnf.d/server.cnf
echo [mysqld] >> /etc/my.cnf.d/server.cnf
echo    innodb_file_per_table=1 >> /etc/my.cnf.d/server.cnf
echo    sql-mode=\"\" >> /etc/my.cnf.d/server.cnf
echo    lower_case_table_names=0 >> /etc/my.cnf.d/server.cnf
echo [embedded] >> /etc/my.cnf.d/server.cnf
echo [mysqld-5.5] >> /etc/my.cnf.d/server.cnf
echo [mariadb] >> /etc/my.cnf.d/server.cnf
echo [mariadb-5.5] >> /etc/my.cnf.d/server.cnf

systemctl restart mariadb

echo      >> /etc/php.ini
echo date.timezone = \"Asia/Taipei\" >> /etc/php.ini

echo    \<VirtualHost *:80\>    >>      /etc/httpd/conf.d/librenms.conf
echo    DocumentRoot /opt/librenms/html/        >>      /etc/httpd/conf.d/librenms.conf
echo    ServerName  librenms.example.com        >>      /etc/httpd/conf.d/librenms.conf
echo    AllowEncodedSlashes NoDecode    >>      /etc/httpd/conf.d/librenms.conf
echo    \<Directory "/opt/librenms/html/"\>     >>      /etc/httpd/conf.d/librenms.conf
echo    Require all granted     >>      /etc/httpd/conf.d/librenms.conf
echo    AllowOverride All       >>      /etc/httpd/conf.d/librenms.conf
echo    Options FollowSymLinks MultiViews       >>      /etc/httpd/conf.d/librenms.conf
echo    \</Directory\>  >>      /etc/httpd/conf.d/librenms.conf
echo    \</VirtualHost\>        >>      /etc/httpd/conf.d/librenms.conf


systemctl enable httpd
systemctl restart httpd

rm -f /etc/httpd/conf.d/welcome.conf

yum install -y policycoreutils-python
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/logs(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/logs(/.*)?'
restorecon -RFvv /opt/librenms/logs/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/rrd(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/rrd(/.*)?'
restorecon -RFvv /opt/librenms/rrd/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/storage(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/storage(/.*)?'
restorecon -RFvv /opt/librenms/storage/
semanage fcontext -a -t httpd_sys_content_t '/opt/librenms/bootstrap/cache(/.*)?'
semanage fcontext -a -t httpd_sys_rw_content_t '/opt/librenms/bootstrap/cache(/.*)?'
restorecon -RFvv /opt/librenms/bootstrap/cache/
setsebool -P httpd_can_sendmail=1

echo    module http_fping 1.0\;  >> /opt/http_fping.tt
echo             >> /opt/http_fping.tt
echo    require {        >> /opt/http_fping.tt
echo    type httpd_t\;   >> /opt/http_fping.tt
echo    class capability net_raw\;       >> /opt/http_fping.tt
echo    class rawip_socket { getopt create setopt write read }\;         >> /opt/http_fping.tt
echo    }        >> /opt/http_fping.tt
echo             >> /opt/http_fping.tt
echo    #============= httpd_t ==============    >> /opt/http_fping.tt
echo    allow httpd_t self:capability net_raw\;  >> /opt/http_fping.tt
echo    allow httpd_t self:rawip_socket { getopt create setopt write read }\;    >> /opt/http_fping.tt

cd /opt
checkmodule -M -m -o http_fping.mod http_fping.tt
semodule_package -o http_fping.pp -m http_fping.mod
semodule -i http_fping.pp

cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf

sed -i "2s/RANDOMSTRINGGOESHERE/${cms}/g" /etc/snmp/snmpd.conf

curl -o /usr/bin/distro https://raw.githubusercontent.com/librenms/librenms-agent/master/snmp/distro
chmod +x /usr/bin/distro
systemctl enable snmpd
systemctl restart snmpd

cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms

cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms


chown -R librenms:librenms /opt/librenms
chmod 770 /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
cd /opt/librenms
yes |./scripts/composer_wrapper.php install --no-dev
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

echo "安裝完成"
echo "請開啟網址: http://"$ip"/install.php"
