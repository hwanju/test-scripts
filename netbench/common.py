# helper functions

def get_nic_name(netif):
    if netif[:2] == 'nf':
        return 'nfnewnic'
    else:    # TODO: if we need more nics to be consider, extend it
        return 'ixgbe'

