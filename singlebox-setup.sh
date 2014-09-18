#!/bin/bash

# Configure for your interfaces.
if [ $# -lt 2 ]; then
	echo "Usage: $0 <tx iface> <rx iface> [config ... ]"
	exit
fi
TX_IFACE=$1
RX_IFACE=$2
shift 2

conf_list="$*"
if [[ "$conf_list" =~ "K:all:on" ]]; then
	conf_list=$(echo $conf_list | sed 's/K:all:on//g')
	all_onoff=on
elif [[ "$conf_list" =~ "K:all:off" ]]; then
	conf_list=$(echo $conf_list | sed 's/K:all:off//g')
	all_onoff=off
fi
if [ "$all_onoff" != "" ]; then
	for func in tso gro gso sg rx tx; do
		for iface in $RX_IFACE $TX_IFACE; do
			conf_list="K:$iface:$func:$all_onoff $conf_list"
		done
	done
fi

echo $conf_list
for conf in $conf_list; do
	if [[ ! $conf =~ : ]]; then
		continue
	fi
	CMD="ethtool -"
	i=1
	while [ true ]; do
		arg=`echo $conf | cut -d: -f$i`
		if [ "$arg" = "" ]; then break; fi
		CMD="$CMD$arg "
		i=$(( $i + 1 ))
	done
	echo $CMD
	$CMD
done

# Real/dummy IPs for cross communication test in the same box
TX_IFACE_REAL_IP=11.0.0.1
TX_IFACE_DUMMY_IP=11.0.0.2
RX_IFACE_REAL_IP=12.0.0.1
RX_IFACE_DUMMY_IP=12.0.0.2
TX_IFACE_NET=11.0.0.0/8
RX_IFACE_NET=12.0.0.0/8

# Interface up w/ real IPs after making irrelevant interfaces down
# make sure loopback is down for REAL communication through two interfaces
echo -n "DOWN"
for iface in lo eth2 eth3 nf0 nf1 nf2 nf3; do
	if [ $iface != $TX_IFACE -a $iface != $RX_IFACE ]; then
		echo -n " $iface"
		ifconfig $iface down 2>/dev/null
	fi
done
ifconfig $TX_IFACE $TX_IFACE_REAL_IP up
ifconfig $RX_IFACE $RX_IFACE_REAL_IP up
echo " and UP $TX_IFACE $RX_IFACE"
ifconfig $TX_IFACE | head -n2
ifconfig $RX_IFACE | head -n2

# Manipulate routing tables for two interfaces to communicate with each other
for i in `seq 2`; do	# due to stale entries by module reload, repeat deletion
	ip route del $TX_IFACE_NET 2>/dev/null
	ip route del $RX_IFACE_NET 2>/dev/null
done
ip route add $TX_IFACE_NET dev $RX_IFACE
ip route add $RX_IFACE_NET dev $TX_IFACE

# Add static ARP entries for dummy IPs for each end to identify the MAC address of its counterpart
arp -i $RX_IFACE -Ds $TX_IFACE_DUMMY_IP $TX_IFACE
arp -i $TX_IFACE -Ds $RX_IFACE_DUMMY_IP $RX_IFACE

# Add NAT for each end to communicate with each other
# the following configuration makes communication take place with dummy IPs below routing table
# while src/dest IP is appropriately modified for packets to be accepted locally with real IPs
iptables -t nat -F
iptables -t nat -A POSTROUTING -j SNAT -s $TX_IFACE_REAL_IP --to-source $TX_IFACE_DUMMY_IP
iptables -t nat -A POSTROUTING -j SNAT -s $RX_IFACE_REAL_IP --to-source $RX_IFACE_DUMMY_IP
iptables -t nat -A PREROUTING -j DNAT  -d $TX_IFACE_DUMMY_IP --to-destination $TX_IFACE_REAL_IP
iptables -t nat -A PREROUTING -j DNAT  -d $RX_IFACE_DUMMY_IP --to-destination $RX_IFACE_REAL_IP

echo "#### Routing table ####"
ip route show
echo
echo "#### ARP table ####"
arp -a
echo
echo "#### NAT table ####"
iptables -t nat -L -n -v
echo 
echo "#### ethtool configuration ####"
echo "[$TX_IFACE]"
ethtool -k $TX_IFACE
ethtool -c $TX_IFACE
echo "[$RX_IFACE]"
ethtool -k $RX_IFACE
ethtool -c $RX_IFACE
