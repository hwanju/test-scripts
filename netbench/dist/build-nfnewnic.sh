#!/bin/bash
[ $# -ge 1 ] && cd $1
[ -e linux-driver ] && exit
git clone https://github.com/hwanju/linux-driver -b tx_revision
cd linux-driver
make NAAS=y
cd apps
make NAAS=y
