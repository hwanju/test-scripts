#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ip addr flush dev $dst_netif
