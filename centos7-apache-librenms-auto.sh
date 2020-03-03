#Centos 7 install Librenms

yum install -y epel-release git net-tools
#get ip
ip=`ifconfig | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | grep -Eo '([0-9]*\.){3}[0-9]*' | grep -v '127.0.0.1'`
#安裝相關套件
rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
yum install -y composer cronie fping git httpd ImageMagick jwhois mariadb mariadb-server mtr MySQL-python net-snmp net-snmp-utils nmap php72w php72w-cli php72w-common php72w-curl php72w-gd php72w-mbstring php72w-mysqlnd php72w-process php72w-snmp php72w-xml php72w-zip python-memcached rrdtool

#新增使用者
useradd librenms -d /opt/librenms -M -r
usermod -a -G librenms apache

#下載LibreNMS
cd /opt
git clone https://github.com/librenms/librenms.git librenms

#設定資料庫(這邊注意要修改密碼，預設為KH_password)
#這邊要研究一下讓用戶指定要取代的密碼
#https://www.itdaan.com/tw/dc30d04966600cd11550349f4ac715b5
#https://hant-kb.kutu66.com/mysql/post_1136980
#https://codertw.com/%E5%89%8D%E7%AB%AF%E9%96%8B%E7%99%BC/392057/
systemctl start mariadb
systemctl enable mariadb
mysql -u root <<EOF
	CREATE DATABASE librenms CHARACTER SET utf8 COLLATE utf8_unicode_ci;
	CREATE USER 'librenms'@'localhost' IDENTIFIED BY 'KH_password';
	GRANT ALL PRIVILEGES ON librenms.* TO 'librenms'@'localhost';
	FLUSH PRIVILEGES;
	exit
EOF

> /etc/my.cnf.d/server.cnf
echo [server] >> /etc/my.cnf.d/server.cnf
echo [mysqld] >> /etc/my.cnf.d/server.cnf
echo 	innodb_file_per_table=1 >> /etc/my.cnf.d/server.cnf
echo 	sql-mode=\"\" >> /etc/my.cnf.d/server.cnf
echo 	lower_case_table_names=0 >> /etc/my.cnf.d/server.cnf
echo [embedded] >> /etc/my.cnf.d/server.cnf
echo [mysqld-5.5] >> /etc/my.cnf.d/server.cnf
echo [mariadb] >> /etc/my.cnf.d/server.cnf
echo [mariadb-5.5] >> /etc/my.cnf.d/server.cnf

systemctl restart mariadb

#設定Web Server
echo date.timezone = \"Asia/Taipei\" >> /etc/php.ini

#設定apache
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

#刪除歡迎頁面
rm -f /etc/httpd/conf.d/welcome.conf


#設定SELinux
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

#建立http_fping.tt
echo	module http_fping 1.0\;	 >> /opt/http_fping.tt
echo		 >> /opt/http_fping.tt
echo	require {	 >> /opt/http_fping.tt
echo	type httpd_t\;	 >> /opt/http_fping.tt
echo	class capability net_raw\;	 >> /opt/http_fping.tt
echo	class rawip_socket { getopt create setopt write read }\;	 >> /opt/http_fping.tt
echo	}	 >> /opt/http_fping.tt
echo		 >> /opt/http_fping.tt
echo	#============= httpd_t ==============	 >> /opt/http_fping.tt
echo	allow httpd_t self:capability net_raw\;	 >> /opt/http_fping.tt
echo	allow httpd_t self:rawip_socket { getopt create setopt write read }\;	 >> /opt/http_fping.tt

cd /opt
checkmodule -M -m -o http_fping.mod http_fping.tt
semodule_package -o http_fping.pp -m http_fping.mod
semodule -i http_fping.pp

#設定防火牆
firewall-cmd --zone public --add-service http
firewall-cmd --permanent --zone public --add-service http
firewall-cmd --zone public --add-service https
firewall-cmd --permanent --zone public --add-service https

#配置snmpd
cp /opt/librenms/snmpd.conf.example /etc/snmp/snmpd.conf

#研究一下修改參數
# Change RANDOMSTRINGGOESHERE to your preferred SNMP community string
# com2sec readonly  default         RANDOMSTRINGGOESHERE
#將第2行的RANDOMSTRINGGOESHERE取代為public
#這邊要研究一下讓用戶指定要取代的變數
sed -i '2s/RANDOMSTRINGGOESHERE/public/g' /etc/snmp/snmpd.conf


#加入排程
cp /opt/librenms/librenms.nonroot.cron /etc/cron.d/librenms
#轉出 logs 目錄下的記錄檔
cp /opt/librenms/misc/librenms.logrotate /etc/logrotate.d/librenms

#設定LibreNMS
chown -R librenms:librenms /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
cd /opt/librenms
./scripts/composer_wrapper.php install --no-dev
chown -R librenms:librenms /opt/librenms
setfacl -d -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/
setfacl -R -m g::rwx /opt/librenms/rrd /opt/librenms/logs /opt/librenms/bootstrap/cache/ /opt/librenms/storage/

#clear
echo "安裝完成"
echo "請開啟網址: http://"$ip"/install.php"
