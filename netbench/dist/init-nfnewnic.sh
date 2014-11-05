#!/bin/bash
[ $# -eq 1 ] || exit
cd $1
killall -9 lbuf_tx lbuf_rx 2>/dev/null  # double-check not to fail rmmod
rmmod nf10 2>/dev/null
insmod linux-driver/nf10.ko reset=1
