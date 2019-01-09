#!/bin/bash

export HOME="/var/lib/voxd"
REPLAY_FLAG="$HOME/replay"
FORCE_REPLAY_FLAG="$HOME/force-reply"

VOXD="/usr/local/bin/voxd"


chown -R voxd:voxd $HOME

# seed nodes come from documentation/seednodes which is
# installed by docker into /etc/voxd/seednodes
SEED_NODES="$(cat /etc/voxd/seednodes | shuf | awk -F' ' '{print $1}')"

ARGS=""

# if user did not pass in any desired
# seed nodes, use the ones above:
if [ -z "$VOXD_SEED_NODES" ]; then
    for NODE in $SEED_NODES ; do
        ARGS+=" --p2p-seed-node=$NODE"
    done
fi

# if user did pass in desired seed nodes, use
# the ones the user specified:
if [ ! -z "$VOXD_SEED_NODES" ]; then
    for NODE in $VOXD_SEED_NODES ; do
        ARGS+=" --p2p-seed-node=$NODE"
    done
fi

if [ ! -z "$VOXD_WITNESS_NAME" ]; then
    ARGS+=" --witness=\"$VOXD_WITNESS_NAME\""
fi

if [ ! -z "$VOXD_MINER_NAME" ]; then
    ARGS+=" --miner=[\"$VOXD_MINER_NAME\",\"$VOXD_PRIVATE_KEY\"]"
    if [ ! -z "$VOXD_MINING_THREADS" ]; then
        ARGS+=" --mining-threads=$VOXD_MINING_THREADS"
    else
        ARGS+=" --mining-threads=$(nproc)"
    fi
fi

if [ ! -z "$VOXD_PRIVATE_KEY" ]; then
    ARGS+=" --private-key=$VOXD_PRIVATE_KEY"
fi

# check existing of flag files for replay

if [ -f "$FORCE_REPLAY_FLAG" ]; then
    rm -f "$FORCE_REPLAY_FLAG"
    rm -f "$REPLAY_FLAG"
    if [ ! -f "$FORCE_REPLAY_FLAG" ] && [ ! -f "$REPLAY_FLAG" ]; then
        ARGS+=" --force-replay-blockchain"
    fi
fi

if [ -f "$REPLAY_FLAG" ]; then
    rm -f "$REPLAY_FLAG"
    if [ ! -f "$REPLAY_FLAG" ]; then
        ARGS+=" --replay-blockchain"
    fi
fi

# overwrite local config with image one
cp /etc/voxd/config.ini $HOME/config.ini

chown voxd:voxd $HOME/config.ini

if [ ! -d $HOME/blockchain ]; then
    if [ -e /var/cache/voxd/blocks.tbz2 ]; then
        # init with blockchain cached in image
        ARGS+=" --replay-blockchain"
        mkdir -p $HOME/blockchain/database
        cd $HOME/blockchain/database
        tar xvjpf /var/cache/voxd/blocks.tbz2
        chown -R voxd:voxd $HOME/blockchain
    fi
fi

# without --data-dir it uses cwd as datadir(!)
# who knows what else it dumps into current dir
cd $HOME

# slow down restart loop if flapping
sleep 1

if [ ! -z "$VOXD_HTTP_ENDPOINT" ]; then
    ARGS+=" --webserver-http-endpoint=$VOXD_HTTP_ENDPOINT"
fi

if [ ! -z "$VOXD_WS_ENDPOINT" ]; then
    ARGS+=" --webserver-ws-endpoint=$VOXD_WS_ENDPOINT"
fi

if [ ! -z "$VOXD_P2P_ENDPOINT" ]; then
    ARGS+=" --p2p-endpoint=$VOXD_P2P_ENDPOINT"
fi

exec chpst -uvoxd \
    $VOXD \
        --data-dir=$HOME \
        $ARGS \
        $VOXD_EXTRA_OPTS \
        2>&1
