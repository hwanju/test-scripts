#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ifconfig $dst_netif up
ip addr flush dev $dst_netif   # don't want irrelevant traffic to bother us
dst_nic=$(get_nic_name $dst_netif)
if [ "$dst_nic" == "nfnewnic" ]; then
  cd linux-driver/apps
  ./lbuf_rx > $resfn &
elif [ "$dst_nic" == "ixgbe" ]; then
  cd netmap/examples
  ./pkt-gen -i $dst_netif -f rx -W > $resfn 2>&1 &
fi
