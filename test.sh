#!/bin/sh

cat <<'EOF' > /etc/init.d/dovecot4
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
