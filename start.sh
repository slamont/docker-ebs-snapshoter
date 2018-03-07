#!/bin/bash

set -e

: "${ACCESS_KEY:?"ACCESS_KEY env variable is required"}"
: "${SECRET_KEY:?"SECRET_KEY env variable is required"}"
CRON_SCHEDULE=${CRON_SCHEDULE:-5 3 * * *}

#TODO: Make this confiurable from ENV
cat > /root/.aws/config <<EOF
[default]
region = ${AWS_REGION:-"us-east-1"}
output = json
EOF

cat > /root/.aws/credentials <<EOF
[default]
aws_access_key_id = ${ACCESS_KEY}
aws_secret_access_key = ${SECRET_KEY}
EOF

case $1 in 
  snapshot-once)
    exec /snapshot.sh -c "Pinned"
    ;;

  schedule)
    echo "Scheduling Snapshot cron:$CRON_SCHEDULE"
    LOGFIFO='/var/log/cron.fifo'
    if [[ ! -e "$LOGFIFO" ]]; then
      mkfifo "$LOGFIFO"
    fi
    CRON_ENV=$(printenv | grep -e '^CUSTOM_' -e '^PATH')
    echo -e "$CRON_ENV\n$CRON_SCHEDULE /snapshot.sh -p -c Scheduled > $LOGFIFO 2>&1" | crontab -
    cron
    tail -f "$LOGFIFO"
    ;;
  *)
    echo "Entrypoint could not understand specified operation. Delegating..."
    exec "$@"
    ;;
esac

