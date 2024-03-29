#!/usr/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$DIR/.." || exit

touch miner-logs1
touch miner-logs2
touch wallet-logs

stack run -- miner --config app/configs/miner_config1.yaml &
stack run -- miner --config app/configs/miner_config2.yaml &

stack run -- wallet --config app/configs/wallet_config.yaml
