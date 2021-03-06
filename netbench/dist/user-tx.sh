#!/bin/bash
### prolog
cd $(dirname $1)/..   # goto netbench testdir (=resdir/..)
. dist/common.sh
### end of prolog

# private args
pkt_len=60
[ $# -ge 1 ] && pkt_len=$1

ethtool -A $src_netif autoneg off rx off tx off
ethtool -K $src_netif tso off lro off gro off gso off tx off rx off
ifconfig $src_netif up
ip addr flush dev $src_netif   # don't want irrelevant traffic to bother us
src_nic=$(get_nic_name $src_netif)
if [ "$src_nic" == "nfnewnic" ]; then
  cd linux-driver/apps
  ./lbuf_tx -l $pkt_len -n 100000000 -f 2 -p | tee -a $resfn
elif [ "$src_nic" == "ixgbe" ]; then
  cd netmap/examples
  ./pkt-gen -i $src_netif -f tx -l $pkt_len -n 100000000 -W | tee -a $resfn
fi
