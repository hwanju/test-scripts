#!/bin/bash
[ $# -ge 1 ] && cd $1
[ -e linux-driver ] && exit
git clone https://github.com/hwanju/linux-driver
cd linux-driver
make NAAS=y install
make -C apps install
