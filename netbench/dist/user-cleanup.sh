#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

killall -INT lbuf_rx 2>/dev/null
ip addr flush dev $dst_netif
