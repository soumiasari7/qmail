#!/bin/sh

#############################################################################
#Created by Soumia Sari <soumia.sari7@gmail.com> 2018-11-25
#############################################################################

yum install gcc gcc-c++ make patch pam-devel openssl* wget vim-common  vim-enhanced -y

#mysql
yum install mysql mysql-server
chkconfig --levels 235 mysqld on
/etc/init.d/mysqld start

#Install Apache
yum -y install httpd
chkconfig --levels 235 httpd on
/etc/init.d/httpd start

#PHP
yum -y install php
/etc/init.d/httpd restart

#Mail server
cd /usr/local/src
wget http://www.qmail.org/netqmail-1.06.tar.gz
wget http://cr.yp.to/ucspi-tcp/ucspi-tcp-0.88.tar.gz
wget http://cr.yp.to/daemontools/daemontools-0.76.tar.gz
wget http://tomclegg.net/qmail/qmail-smtpd-auth-0.31.tar.gz
wget http://www.dovecot.org/releases/1.2/dovecot-1.2.6.tar.gz
mkdir /package
mv /usr/local/src/daemontools-0.76.tar.gz /package

#Create users and groups
groupadd nofiles
useradd -g nofiles -d /var/qmail qmaild
useradd -g nofiles -d /var/qmail qmaill
useradd -g nofiles -d /var/qmail qmailp
useradd -g nofiles -d /var/qmail/alias alias
groupadd qmail
useradd -g qmail -d /var/qmail qmailq
useradd -g qmail -d /var/qmail qmailr
useradd -g qmail -d /var/qmail qmails

#Compile & Install
cd /usr/local/src
tar -xzvf netqmail-1.06.tar.gz

#Apply the SMTP patch
cd /usr/local/src
tar -xzvf qmail-smtpd-auth-0.31.tar.gz
cd qmail-smtpd-auth-0.31/
cp README.auth base64.c base64.h ../netqmail-1.06
patch-d ../netqmail-1.06 < auth.patch

#Compile & install qmail
cd /usr/local/src/netqmail-1.06
make setup check

#./config-fast mail.yourdomain.com

useradd admin;
cd ~alias;
echo admin >.qmail-postmaster;
echo admin > .qmail-mailer-daemon;
echo admin > .qmail-root;
echo admin > .qmail-abuse;
chmod 644 ~alias/.qmail* ;
#Create Maildir for “admin” user
#su admin
#this command run under admin user
#/var/qmail/bin/maildirmake ~/Maildir

#Configure Qmail to use Maildir

#Create “/var/qmail/rc” with following contents.

cat <<EOF > /var/qmail/rc
#!/bin/sh
set -x
# Using stdout for logging
# Using control/defaultdelivery from qmail-local to deliver messages by default
exec env -PATH="/var/qmail/bin:$PATH" \
qmail-start "`cat /var/qmail/control/defaultdelivery`"  
EOF

chmod 755 /var/qmail/rc

#Create “/var/qmail/control/defaultdelivery” file.
echo ./Maildir/ >/var/qmail/control/defaultdelivery

#Replace Sendmail binaries
chmod 0 /usr/lib/sendmail ;
chmod 0 /usr/sbin/sendmail ;
mv /usr/lib/sendmail /usr/lib/sendmail.bak ;
mv /usr/sbin/sendmail /usr/sbin/sendmail.bak ;
ln -s /var/qmail/bin/sendmail /usr/lib/sendmail ;
ln -s /var/qmail/bin/sendmail /usr/sbin/sendmail ;

#Install ucspi-tcp
cd /usr/local/src/
tar -xzvf ucspi-tcp-0.88.tar.gz
#Patch ucspi-tcp with “ucspi-tcp-0.88.errno.patch” provided with net qmail.
cd ucspi-tcp-0.88
patch < /usr/local/src/netqmail-1.06/other-patches/ucspi-tcp-0.88.errno.patch
make
make setup check

#Install daemontools
cd /package
tar -xzvf daemontools-0.76.tar.gz
#Patch daemontools with “daemontools-0.76.errno.patch” provided with net qmail.
cd /package/admin/daemontools-0.76/src
patch < /usr/local/src/netqmail-1.06/other-patches/daemontools-0.76.errno.patch
cd ..
./package/install

#Qmail Startup script
cd /var/qmail/bin
wget http://lifewithqmail.org/qmailctl-script-dt70
mv qmailctl-script-dt70 qmailctl
chmod 755 /var/qmail/bin/qmailctl
ln -s /var/qmail/bin/qmailctl /usr/bin

#Setup qmail-send & qmail-smtpd
mkdir -p /var/qmail/supervise/qmail-send/log
mkdir -p /var/qmail/supervise/qmail-smtpd/log

#Create supervise script for qmail-send with name “/var/qmail/supervise/qmail-send/run”.
#The file should have following contents.
cat <<EOF > /var/qmail/supervise/qmail-send/run
#!/bin/sh
exec /var/qmail/rc
EOF

#Create qmail-send log daemon supervise script with name “/var/qmail/supervise/qmail-send/log/run”.
#The script should have following contents
cat <<EOF > /var/qmail/supervise/qmail-send/log/run
#!/bin/sh
exec /usr/local/bin/setuidgid qmaill /usr/local/bin/multilog t /var/log/qmail
EOF
      
#Create qmail-smtpd daemon supervise script with name “/var/qmail/supervise/qmail-smtpd/run”.
#The script should have following contents
cat <<EOF > /var/qmail/supervise/qmail-smtpd/run
#!/bin/sh
set -x
QMAILDUID=`id -u qmaild`
NOFILESGID=`id -g qmaild`
MAXSMTPD=`cat /var/qmail/control/concurrencyincoming`
LOCAL=`head -1 /var/qmail/control/me`
if [ -z "$QMAILDUID"-o -z "$NOFILESGID" -o -z "$MAXSMTPD" -o -z "$LOCAL" ]; then
echo QMAILDUID, NOFILESGID, MAXSMTPD, or LOCAL is unset in
7
echo /var/qmail/supervise/qmail-smtpd/run
exit 1
fi
if [ ! -f /var/qmail/control/rcpthosts ]; then
echo "No /var/qmail/control/rcpthosts!"
echo "Refusing to start SMTP listener because it’ll create an open relay"
exit 1
fi
exec /usr/local/bin/softlimit -m 9000000 \
/usr/local/bin/tcpserver -v -R -l "$LOCAL" -x /etc/tcp.smtp.cdb -c "$MAXSMTPD" \
-u 509 -g 509 0 smtp /var/qmail/bin/qmail-smtpd 2>&1 
EOF

#Create the concurrencyincoming control file.
echo 20 >/var/qmail/control/concurrencyincoming
chmod 644 /var/qmail/control/concurrencyincoming

#Create qmail-smtpd log daemon supervise script with name“/var/qmail/supervise/qmail-smtpd/log/run”.
#The script should have following contents
cat <<EOF > /var/qmail/supervise/qmail-smtpd/log/run
#!/bin/sh
exec /usr/local/bin/setuidgid qmaill /usr/local/bin/multilog t /var/log/qmail/smtpd
EOF
     
#Create the log directories and add execute permissions on the run scripts.
mkdir -p /var/log/qmail/smtpd
chown qmaill /var/log/qmail
chown qmaill /var/log/qmail/smtpd
chmod 755 /var/qmail/supervise/qmail-send/run
chmod 755 /var/qmail/supervise/qmail-send/log/run
chmod 755 /var/qmail/supervise/qmail-smtpd/run
chmod 755 /var/qmail/supervise/qmail-smtpd/log/run
ln -s /var/qmail/supervise/qmail-send /service/qmail-send
ln -s /var/qmail/supervise/qmail-smtpd /service/qmail-smtpd
svscanboot &
start
qmailctl stat
##############################################################################################################

##############################################################################################################

#Install Vpopmail
mkdir -p /usr/local/src/build
cd /usr/local/src/build
wget https://sourceforge.net/projects/vpopmail/files/latest/download/vpopmail-5.4.33.tar.gz
tar xvzf vpopmail-5.4.33.tar.gz
cd vpopmail-5.4.33
groupadd vchkpw
mkdir /var/vpopmail
useradd -g vchkpw -d /var/vpopmail vpopmail
./configure --enable-clear-passwd=y --enable-logging=y --enable-auth-logging=y --enable-roaming-users=y --enable-ip-alias-domains=y
make
make install-strip

#Download dovecot
cd /usr/local/src
tar -xzvf dovecot-1.2.6.tar.gz
cd dovecot-1.2.6
./configure --with-ioloop=IOLOOP --with-notify=NOTIFY --with-ssl=openssl --with-passwd --with-passwd-file --with-shadow --with-pam --with-checkpassword --with-vpopmail --with-static-userdb
make
make install
mkdir -p /etc/ssl/certs/
mkdir -p /etc/ssl/private/
cd /usr/local/src/dovecot-1.2.6/doc/
chmod 755 mkcert.sh
./mkcert.sh

#Create /etc/pam.d/dovecot
cat <<EOF > /etc/pam.d/dovecot
#auth required pam_unix.so nullok
#account required pam_unix.so
EOF

cp -pv /usr/local/etc/dovecot-example.conf /usr/local/etc/dovecot.conf

##############################Edit dovecot.conf#########################
##to complete!
########################################################################"

#Create /etc/init.d/dovecot with following contents.
cat <<EOF > /etc/init.d/dovecot
#!/bin/bash
# /etc/rc.d/init.d/dovecot
# Starts the dovecot daemon
# chkconfig: – 65 35
# description: Dovecot Imap Server
# processname: dovecot
# Source function library.
. /etc/init.d/functions
test -x /usr/local/sbin/dovecot || exit 0
RETVAL=0
prog="Dovecot Imap"
start() {
echo -n $"Starting $prog: "
daemon /usr/local/sbin/dovecot
RETVAL=$?
[ $RETVAL -eq 0 ] && touch /var/lock/subsys/dovecot
echo
}
stop() {
echo -n $"Stopping $prog: "
killproc /usr/local/sbin/dovecot
RETVAL=$?
[ $RETVAL -eq 0 ] && rm -f /var/lock/subsys/dovecot
echo
}
# See how we were called.
case "$1" in
start)
start
;;
stop)
stop
;;
reload|restart)
stop
start
RETVAL=$?
;;
condrestart)
if [ -f /var/lock/subsys/dovecot ]; then
stop
start
fi
;;
status)
status /usr/local/sbin/dovecot
RETVAL=$?
;;
*)
echo $"Usage: $0 {condrestart|start|stop|restart|reload|status}"
exit 1
esac
exit $RETVAL
EOF

chmod 755 /etc/init.d/dovecot

#Create dovecot user
useradd dovecot
#Start dovecot
/etc/init.d/dovecot start

#######
cd /service/qmail-smtpd
cp -pv run run.bak
#Modify run file as given below.

#vim run
cat <<EOF > /service/qmail-smtpd/run
#!/bin/sh
set -x
QMAILDUID=`id -u qmaild`
NOFILESGID=`id -g qmaild`
MAXSMTPD=`cat /var/qmail/control/concurrencyincoming`
LOCAL=`head -1 /var/qmail/control/me`
if [ -z "$QMAILDUID" -o -z "$NOFILESGID" -o -z "$MAXSMTPD" -o -z "$LOCAL" ]; then
echo QMAILDUID, NOFILESGID, MAXSMTPD, or LOCAL is unset in
echo /var/qmail/supervise/qmail-smtpd/run
exit 1
fi
if [ ! -f /var/qmail/control/rcpthosts ]; then
echo "No /var/qmail/control/rcpthosts!"
echo "Refusing to start SMTP listener because it’ll create an open relay"
exit 1
fi
exec /usr/local/bin/softlimit -m 9000000 \
/usr/local/bin/tcpserver -v -R -l "$LOCAL" -x /etc/tcp.smtp.cdb -c "$MAXSMTPD" \
-u 509 -g 509 0 smtp /var/qmail/bin/qmail-smtpd 2>&1
EOF

#Note 1: 509 is the UID & GID of vpopmail

###########
cp -pv /var/vpopmail/bin/vchkpw /var/vpopmail/bin/vchkpw.bak
chmod 755 /var/vpopmail/
chmod 4755 /var/vpopmail/bin/vchkpw
chown root.root /var/vpopmail/bin/vchkpw
qmailctl stop
qmailctl start
qmailctl stat
/etc/init.d/dovecot restart

##############
#Setting up the tcpserver access files
mkdir -m 755 /etc/tcp
cd /etc/tcp
wget http://qmail.jms1.net/etc-tcp-makefile
mv etc-tcp-makefile Makefile

#At this point it should be ready to go- all you need to do is create the "smtp" file

echo " 127.:allow,RELAYCLIENT="" :allow " > /etc/tcp/smtp
make

##QmailAdmin
cd /usr/local/src
wget http://garr.dl.sourceforge.net/project/qmailadmin/qmailadmin-devel/qmailadmin-1.2.16.tar.gz
tar zxvf qmailadmin-1.2.16.tar.gz
cd qmailadmin-1.2.16
./configure
make
make install-strip

##Install Squirrelmail
cd /usr/local/src
wget https://sourceforge.net/projects/squirrelmail/files/latest/download/squirrelmail-webmail-1.4.22.tar.gz
tar xfvz squirrelmail-webmail-1.4.22.tar.gz
mv squirrelmail-webmail-1.4.22 /var/www/html
cd /var/www/html
mv squirrelmail-webmail-1.4.22 squirrelmail
cd squirrelmail
#config/conf.pl
#Configure squirrelmail as necessary.
mkdir -p /var/local/squirrelmail/data/
mkdir -p /var/local/squirrelmail/attach/
chmod -R 755 /var/www/html/squirrelmail
chown -R apache.apache /var/local/squirrelmail/attach/ /var/local/squirrelmail/data/


################avoid error
echo '127.:allow,RELAYCLIENT=""' >>/etc/tcp.smtp
qmailctl cdb

##Add ssl
yum install crypto-utils
yum -y install mod_ssl 
#echo +77 /i /etc/httpd/conf.d/ssl.conf 
# line 77: uncomment
#DocumentRoot "/var/www/html"
# line 78: uncomment and specify the server name
#ServerName www.srv.world:443

