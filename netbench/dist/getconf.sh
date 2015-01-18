#!/bin/bash
[ $# -eq 3 ] || exit
netif=$1
site=$2
resdir=$3
pci_id=`find /sys/devices -name $netif | cut -d/ -f6 | cut -d: -f2-`
gen=`lspci -s $pci_id -vv | perl -e 'while(<>) { if (/LnkSta:\s+Speed\s+(.+)GT\/s,\s+Width\s+x(\d+)/ && $2 == 8) { print "G1" if $1 == 2.5; .5; print "G2" if $1 == 5; print "G3" if $1 == 8; } }'`
lspci -s $pci_id -vv > $resdir/${netif}$site-$gen.lspci
echo -n $gen
