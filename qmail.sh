#!/bin/sh

#############################################################################
Soumia Sari <soumia.sari@gmail.com> 2018-11-25
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
wget http://ftp.nsysu.edu.tw/FreeBSD/ports/local-distfiles/bdrewery/qmail/qmail-smtpd-auth-0.31.tar.gz
wget http://www.dovecot.org/releases/1.2/dovecot-1.2.6.tar.gz
wget http://archive.apache.org/dist/spamassassin/Mail-SpamAssassin-3.3.2.tar.gz
wget http://mirror.trouble-free.net/sources/clamav-0.97.6.tar.gz
wget http://shupp.org/software/toaster-scripts-0.9.1.tar.gz
wget http://www.pldaniels.com/ripmime/ripmime-1.4.0.10.tar.gz
wget http://garr.dl.sourceforge.net/project/simscan/simscan/simscan-1.4.0/simscan-1.4.0.tar.gz
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

echo  " #!/bin/sh
       set -x
       # Using stdout for logging
       # Using control/defaultdelivery from qmail-local to deliver messages by default
       exec env -PATH="/var/qmail/bin:$PATH" \
       qmail-start "`cat /var/qmail/control/defaultdelivery`"  " >> /var/qmail/rc

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
cd /var/usr/src
wget http://lifewithqmail.org/qmailctl-script-dt70
mv qmailctl-script-dt70 qmailctl
chmod 755 /var/qmail/bin/qmailctl
ln -s /var/qmail/bin/qmailctl /usr/bin

#Setup qmail-send & qmail-smtpd
mkdir –p /var/qmail/supervise/qmail-send/log
mkdir –p /var/qmail/supervise/qmail-smtpd

#Create supervise script for qmail-send with name “/var/qmail/supervise/qmail-send/run”.
#The file should have following contents.
echo "#!/bin/sh
exec /var/qmail/rc " >> /var/qmail/supervise/qmail-send/run 

#Create qmail-send log daemon supervise script with name “/var/qmail/supervise/qmail-send/log/run”.
#The script should have following contents
echo " #!/bin/sh
      exec /usr/local/bin/setuidgid qmaill /usr/local/bin/multilog t /var/log/qmail" >> /var/qmail/supervise/qmail-send/log/run
      
#Create qmail-smtpd daemon supervise script with name “/var/qmail/supervise/qmail-smtpd/run”.
#The script should have following contents
echo " #!/bin/sh
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
-u 509 -g 509 0 smtp /var/qmail/bin/qmail-smtpd 2>&1 " >> /var/qmail/supervise/qmail-smtpd/run

#Create the concurrencyincoming control file.
echo 20 >/var/qmail/control/concurrencyincoming
chmod 644 /var/qmail/control/concurrencyincoming

#Create qmail-smtpd log daemon supervise script with name“/var/qmail/supervise/qmail-smtpd/log/run”.
#The script should have following contents
echo "#!/bin/sh
     exec /usr/local/bin/setuidgid qmaill /usr/local/bin/multilog t /var/log/qmail/smtpd " >> /var/qmail/supervise/qmail-smtpd/log/run
     
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
qmailctl start
qmailctl stat

##############################################################################################################

##############################################################################################################

#Install Vpopmail



