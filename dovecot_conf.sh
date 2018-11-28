protocols = imap imaps pop3 pop3s
disable_plaintext_auth = no
ssl_cert_file = /etc/ssl/certs/dovecot.pem
ssl_key_file = /etc/ssl/private/dovecot.pem
first_valid_uid = 89
first_valid_gid = 1
passdb vpopmail {
args = webmail=127.0.0.1
}
userdb vpopmail {
args = quota_template=quota_rule=*:backend=%q
}
mail_location = maildir:/var/vpopmail/domains/%d/%n/Maildir

