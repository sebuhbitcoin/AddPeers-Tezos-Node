#!/bin/bash

#
# 20210119 - Use the new --endpoint flag
#          - Added verbose logging
#
# 20200608 - Updated to TzKt API
#
# 20191029 - Added /v3/network back in. 
#            Thanks to Baking-Bad and their Mystique API
#          - Added some more check logic
#          - Added '>' prefix so you can tell who is outputting
#
# 20191025 - Filtering improvements @FreedomPrevails
#
# 20191019 - Babylon Update
# TZScan was the only public place to find a listing of all connected
# tezos nodes. With tzscan offline, this information is no longer
# accessible. The script below will still attempt to maintain connections
# to the foundation nodes.

# The tezos-admin-client binary will output 'Error' messages in
# most cases, even when already connected to a peer.
#
# If you found this script helpful, send us a tip!
# Baking Tacos! tz1RV1MBbZMR68tacosb7Mwj6LkbPSUS1er1
#

# Where is tezos installed?
TZPATH=/home/ubuntu/tezos
PARAMS="--endpoint http://127.0.0.1:8732"

# Sanity Tests
command -v $TZPATH/tezos-admin-client >/dev/null 2>&1 || { echo >&2 "Cannot find 'tezos-admin-client' in $TZPATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo >&2 "'jq' is required. Please install it."; exit 1; }
command -v curl >/dev/null 2>&1 || { echo >&2 "'curl' is required. Please install it."; exit 1; }
command -v dig >/dev/null 2>&1 || { echo >&2 "'dig' is required. Please install it."; exit 1; }
command -v ss >/dev/null 2>&1 || { echo >&2 "'ss' is required. Please install it."; exit 1; }

# Cache connections list
NET=$(ss -nt state established)

newpeers=0

# get foundation nodes
echo "> Getting list of foundation nodes..."
for i in dubnodes franodes sinnodes nrtnodes pdxnodes; do
    for j in `dig $i.tzbeta.net +short`; do
        if [ -z "$(echo $NET | grep $j)" ]; then
            echo "> Connecting foundation $j..."
            $TZPATH/tezos-admin-client $PARAMS connect address [$j]:9732
            if [ $? -eq 0 ]; then
                ((newpeers++))
                #  echo "> New connection to $j established"
            fi
        fi
    done
done

# Public Nodes
# Loop over pages from mystique API.
APIDOMAIN="services.tzkt.io"

echo "> Fetching list of public nodes from https://$APIDOMAIN/v1/network"
for page in {0..5}; do

    # get array of peers
    peers=($(curl -s "https://$APIDOMAIN/v1/network?state=running&p=$page&n=50" | jq -r '.[] | .point_id' | xargs))
    if [ ${#peers[@]} -eq 0 ]; then
        # exit loop, no results for page
        echo "> ... complete"
        break
    fi

    # loop through peers array
    echo "> Processing list of public nodes..."
    for i in ${peers[@]}; do

        # handle ipv4 or ipv6
        numparts=$(echo $i | awk -F: '{print NF}')
        basenum=$((numparts-1))
        port=$(echo $i | cut -d: -f$numparts)
        base=$(echo $i | cut -d: -f1-$basenum)
        formatted="[$base]:$port"

        if [ -z "$(echo $NET | grep $base)" ]; then
            echo "> Connecting to $formatted..."
            $TZPATH/tezos-admin-client $PARAMS connect address $formatted
            if [ $? -eq 0 ]; then
                ((newpeers++))
                #echo "> New connection to $j established"
            fi
        fi
    done
done

# how many peers do we have now? how many did we add?
numpeers=$($TZPATH/tezos-admin-client $PARAMS p2p stat | grep "MAINNET" | wc -l)
echo "> Added $newpeers peers. Currently $numpeers connected. Done."
