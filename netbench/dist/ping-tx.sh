#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ifconfig $src_netif $src_ip up
ping -I $src_netif $dst_ip -c 100 | tee -a $3
ip addr flush dev $src_netif
