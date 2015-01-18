#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

ethtool -A $dst_netif autoneg off rx off tx off   # disable flow control
ethtool -K $dst_netif tso off lro off gro off gso off tx off rx off
ifconfig $dst_netif up
ip addr flush dev $dst_netif   # don't want irrelevant traffic to bother us
dst_nic=$(get_nic_name $dst_netif)
if [ "$dst_nic" == "nfnewnic" ]; then
  cd linux-driver/apps
  ./lbuf_rx -f 2 -p >> $resfn &
elif [ "$dst_nic" == "ixgbe" ]; then
  cd netmap/examples
  ./pkt-gen -i $dst_netif -f rx -W >> $resfn 2>&1 &
fi
