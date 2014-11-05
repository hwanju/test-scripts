#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ifconfig $dst_netif $dst_ip up
