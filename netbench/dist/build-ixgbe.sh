#!/bin/bash
[ $# -ge 1 ] && cd $1
[ -e netmap ] && exit
git clone https://code.google.com/p/netmap
cd netmap/LINUX
make
cd ../examples
make
