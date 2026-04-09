#!/bin/sh
/usr/local/bin/sync.sh &
exec crond -f -d 8
