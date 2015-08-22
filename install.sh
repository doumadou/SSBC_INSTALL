#!/bin/bash
#########################################################################
# File Name: install.sh
# Author: Gavin Tao
# mail: gavin.tao17@gmail.com
# Created Time: 2015年08月22日 星期六 14时06分58秒
#########################################################################

set -x 
yum install -y gcc gcc-c++ mariadb mariadb-server mariadb-devel python-devel git wget 
if [ ! -e get-pip.py ];then
	wget https://raw.github.com/pypa/pip/master/contrib/get-pip.py
fi

python get-pip.py || exit -1

if [ ! -e ssbc ]; then
	git clone https://github.com/78/ssbc
fi

cd ssbc &&  pip install -r requirements.txt && cd -

cd ssbc
sed -i "s/'USER': 'root',/'USE': 'root','PASSWORD':'root',/g"  ssbc/settings.py
sed -i "s/SRC_PASS = ''/SRC_PASS = 'root'/g" workers/index_worker.py
sed -i "s/DB_PASS = ''/DB_PASS = 'root'/g" workers/simdht_worker.py
sed -i "s/showAds();/\/\/showAds();/g" web/static/js/ssbc.js
cd -

echo "start mariadb ....."

service mariadb start
mysqladmin -u root password root

mysql -u root -proot -e "create database ssbc default character set utf8;"

yum install -y unixODBC unixODBC-devel postgresql-libs

if [ ! -f sphinx-2.2.9-1.rhel7.x86_64.rpm ]; then
	wget http://sphinxsearch.com/files/sphinx-2.2.9-1.rhel7.x86_64.rpm 
fi

rpm -ivh sphinx-2.2.9-1.rhel7.x86_64.rpm

mkdir -vp /data/bt/index/{db,binlog} /tem/downloads && chmod 777 /data -R && chmod 777 /tem -R

systemctl stop firewalld.service

cd  ssbc 
indexer -c sphinx.conf --all
searchd --config  ./sphinx.conf

python manage.py makemigrations
python manage.py migrate

python manage.py createsuperuser --noinput --username root --email root@root.com
wget https://raw.githubusercontent.com/doumadou/ssbc/master/auth.py
python auth.py





cd workers
nohup python simdht_worker.py >/dev/zero &
nohup python index_worker.py >/dev/zero &
cd -
nohup python manage.py runserver 0.0.0.0:80 > /dev/zero &
