#!/bin/bash
[ $# -eq 1 ] || exit
cd $1
killall -9 pkt-gen 2>/dev/null  # double-check not to fail rmmod
rmmod ixgbe 2>/dev/null
rmmod netmap 2>/dev/null
insmod netmap/LINUX/netmap.ko
insmod netmap/LINUX/ixgbe/ixgbe.ko allow_unsupported_sfp=1
