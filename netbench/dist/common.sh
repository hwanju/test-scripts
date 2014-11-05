# result_file src_netif src_ip dst_netif dst_ip
[ $# -ge 5 ] || exit
resfn=$1; src_netif=$2; src_ip=$3; dst_netif=$4; dst_ip=$5
shift 5

get_nic_name(){
  if [[ "$1" =~ "nf" ]]; then
    echo nfnewnic
  else
    echo ixgbe
  fi
}
