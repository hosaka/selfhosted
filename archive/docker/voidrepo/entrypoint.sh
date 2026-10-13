#!/bin/sh

envsubst </usr/local/share/crontab.template >/var/spool/cron/crontabs/root
chmod 600 /var/spool/cron/crontabs/root

/usr/local/bin/sync.sh && exec crond -f -d 8 -c /var/spool/cron/crontabs
