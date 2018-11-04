#!/bin/bash

echo /tmp/core | tee /proc/sys/kernel/core_pattern
ulimit -c unlimited

VERSION=`cat /etc/steemdversion`
STEEMD="/usr/local/steemd-full/bin/steemd"

chown -R steemd:steemd $HOME
ARGS=""

# if user did pass in desired seed nodes, use
# the ones the user specified:
if [[ ! -z "$STEEMD_SEED_NODES" ]]; then
    for NODE in $STEEMD_SEED_NODES ; do
        ARGS+=" --p2p-seed-node=$NODE"
    done
fi

if [[ ! -z "$STEEMD_WITNESS_NAME" ]]; then
    ARGS+=" --witness=\"$STEEMD_WITNESS_NAME\""
fi


if [[ ! -z "$STEEMD_PRIVATE_KEY" ]]; then
    ARGS+=" --private-key=$STEEMD_PRIVATE_KEY"
fi

if [[ ! -z "$STEEMD_ENABLE_SLATE_PRODUCTION" ]]; then
    ARGS+=" --enable-stale-production --required-participation=0"
fi

if [[ ! -z "$TRACK_ACCOUNT" ]]; then
    if [[ ! "$USE_WAY_TOO_MUCH_RAM" ]]; then
        ARGS+=" --plugin=account_history_rocksdb --plugin=account_history_api"
    fi
    ARGS+=" --account-history-rocksdb-track-account-range=[\"$TRACK_ACCOUNT\",\"$TRACK_ACCOUNT\"]"
fi

if [[ ! "$DISABLE_SCALE_MEM" ]]; then
   ARGS+=" --shared-file-full-threshold=9500 --shared-file-scale-rate=1000"
fi

NOW=`date +%s`
STEEMD_FEED_START_TIME=`expr $NOW - 1209600`

ARGS+=" --follow-start-feeds=$STEEMD_FEED_START_TIME"

# overwrite local config with image one
if [[ "$USE_FULL_WEB_NODE" ]]; then
  cp /etc/steemd/fullnode.config.ini $HOME/config.ini
elif [[ "$IS_BROADCAST_NODE" ]]; then
  cp /etc/steemd/config-for-broadcaster.ini $HOME/config.ini
elif [[ "$IS_AH_NODE" ]]; then
  cp /etc/steemd/config-for-ahnode.ini $HOME/config.ini
elif [[ "$IS_OPSWHITELIST_NODE" ]]; then
  cp /etc/steemd/fullnode.opswhitelist.config.ini $HOME/config.ini
else
  cp /etc/steemd/config.ini $HOME/config.ini
fi

chown steemd:steemd $HOME/config.ini

if [[ ! -d $HOME/blockchain ]]; then
    if [[ -e /var/cache/steemd/blocks.tbz2 ]]; then
        # init with blockchain cached in image
        ARGS+=" --replay-blockchain"
        mkdir -p $HOME/blockchain/database
        cd $HOME/blockchain/database
        tar xvjpf /var/cache/steemd/blocks.tbz2
        chown -R steemd:steemd $HOME/blockchain
    fi
else
   ARGS+=" --tags-skip-startup-update"
fi

cd $HOME

# slow down restart loop if flapping
sleep 1

mv /etc/nginx/nginx.conf /etc/nginx/nginx.original.conf
cp /etc/nginx/steemd.nginx.conf /etc/nginx/nginx.conf

exec chpst -usteemd \
    $STEEMD \
    --webserver-ws-endpoint=0.0.0.0:8090 \
    --webserver-http-endpoint=0.0.0.0:8090 \
    --p2p-endpoint=0.0.0.0:2001 \
    --data-dir=$HOME \
    $ARGS \
    $STEEMD_EXTRA_OPTS \
    2>&1

