#!/usr/bin/env python

import sys
import getopt
import os
import time
import subprocess
import glob
from common import *

testdir = '/root/netbench'
resdir = None
nicpairs = None
tests = None
avail_tests = ('iperf', 'ping', 'user')
remote_host = None
host_prefix_cmds = {'local': ''}
ip_prefix = '192.168.234.'
last_host_id = 1
host_ips = {'local': {}, 'remote': {}}
pci_gens = {'local': {}, 'remote': {}}
priv_args = ['']
LTOR, RTOL = 1, 2
direction = LTOR | RTOL
nr_runs = 1

def get_ip():
    global last_host_id
    last_host_id += 1
    return ip_prefix + '%d' % last_host_id

def show_usage_and_exit():
    sys.stdout = sys.stderr
    print "%s -h <remote host> -n <nic pairs> [-t <test1[,test2,...]>] [-d <test dir>] [-p <private arg1[,arg2,...]>] [-D direction]" % sys.argv[0]
    print "\tnic pairs: <local netif>-<remote netif>[,...] (e.g., nf0-eth9,eth8-eth9)"
    print "\tprivate args: each arg is for one run and contains period-separated multiple args to each run (e.g., 60.1000,128.2000)"
    print "\tdirection: local-to-remote=1, remote-to-local=2, both=3"
    print "\tavailable tests:", avail_tests
    print "\tdefault testdir:", testdir
    sys.exit(-1)

def path_exists(name, err_if_exist=None):
    existence = os.path.exists(name)
    if err_if_exist != None and existence == err_if_exist:
        print >>sys.stderr, "Error: %s %s" % (name, "exists" if err_if_exist else "doesn't exist")
        sys.exit(-1)
    return existence

def sanity_check():
    if remote_host == None:
        show_usage_and_exit()
    elif len(nicpairs) < 1 or len(filter(lambda x: len(x) != 2, nicpairs)) > 0:
        show_usage_and_exit()
    elif tests == None or not set(tests).issubset(set(avail_tests)):
        show_usage_and_exit()
    elif priv_args[0] != '' and len(tests) != 1:
        print >>sys.stderr, "Error: private args must not be used with multiple tests"
        show_usage_and_exit()

def run_cmd(cmd, output=False, verbose=False):
    try:
        if verbose:
            print cmd
        if output:
            return subprocess.check_output(cmd.split())
        subprocess.check_call(cmd.split())
        return True
    except:
        if verbose:
            print >>sys.stderr, "Error: failed to execute '%s'" % cmd
        if output:
            return ""
        return False

def setup_hosts():
    global resdir
    if resdir == None:
        resdir = testdir + '/' + 'results-' + ','.join(tests) + time.strftime("-%b%d%Y_%H%M%S")
    for prefix in host_prefix_cmds.itervalues():
        run_cmd('%s mkdir -p %s' % (prefix, resdir))

    # save cmdline arguments for reproducing the test
    f = open('%s/cmd' % resdir, 'w')
    f.write('%s\n' % ' '.join(sys.argv))
    f.close()

    # deploy dist scripts
    run_cmd('cp -a dist %s/' % testdir)
    run_cmd('scp -r dist root@%s:%s/' % (remote_host, testdir))

    # run build scripts
    for prefix in host_prefix_cmds.itervalues():
        for script in glob.glob('%s/dist/build-*.sh' % testdir):
            run_cmd('%s %s %s' % (prefix, script, testdir))

def init_hosts():
    for site in host_prefix_cmds:
        # run all init scripts to invalidate all pre-assigned IPs
        for script in glob.glob('%s/dist/init-*.sh' % testdir):
            run_cmd('%s %s %s' % (host_prefix_cmds[site], script, testdir))
        # assign IP address to netifs to be tested
        for netif in set([x[0 if site == 'local' else 1] for x in nicpairs]):
            nic = get_nic_name(netif)
            ip = get_ip()
            pci_gen = run_cmd('%s %s/dist/getconf.sh %s %s %s' % (host_prefix_cmds[site], testdir, netif, site[0], resdir), output=True)
            host_ips[site][netif] = ip
            pci_gens[site][netif] = pci_gen
            print '%s: %s(%s,%s) is assigned %s' % (site, netif, pci_gen, nic, ip)

def run_test(test, lif, rif, l2r):
    # l2r: if local to remote, True, otherwise False

    tx_script = '%s/dist/%s-tx.sh' % (testdir, test)
    rx_script = '%s/dist/%s-rx.sh' % (testdir, test)
    cleanup_script = '%s/dist/%s-cleanup.sh' % (testdir, test)

    tx_if = lif if l2r else rif
    tx_site = 'local' if l2r else 'remote'
    tx_ip = host_ips[tx_site][lif] if l2r else host_ips[tx_site][rif]

    rx_if = rif if l2r else lif
    rx_site = 'remote' if l2r else 'local'
    rx_ip = host_ips[rx_site][rif] if l2r else host_ips[rx_site][lif]

    # if -p is specified, it determines # of runs for each test with different priv args
    # otherwise, priv_args has one empty string, so test is conducted once
    for parg in priv_args:
        result_fn_prefix = resdir + "/%s_%s%s%s-%s%s%s%s" % (test, tx_if, pci_gens[tx_site][tx_if], tx_site[0], rx_if, pci_gens[rx_site][rx_if], rx_site[0], "_%s" % parg if parg != '' else '')
        # from 2nd arg (1st arg is result_fn)
        remaining_args = '%s %s %s %s %s' % (tx_if, tx_ip, rx_if, rx_ip, ' '.join(parg.split('.')))
        # prepare rx if any
        if path_exists(rx_script):
            result_fn = result_fn_prefix + '_rx.out'
            run_cmd('%s %s %s %s' % (host_prefix_cmds[rx_site], rx_script, result_fn, remaining_args), verbose=True)

        time.sleep(3)   # roughly wait for the rx to get ready

        # start tx
        result_fn = result_fn_prefix + '_tx.out'
        run_cmd('%s %s %s %s' % (host_prefix_cmds[tx_site], tx_script, result_fn, remaining_args), verbose=True)

        # cleanup rx if any
        if path_exists(cleanup_script):
            result_fn = result_fn_prefix + '_rx.out'
            run_cmd('%s %s %s %s' % (host_prefix_cmds[rx_site], cleanup_script, result_fn, remaining_args), verbose=True)

def start_tests():
    for test in tests:
        for i in range(nr_runs):
            for lif, rif in nicpairs:    # local netif, remote netif
                if direction & LTOR:
                    run_test(test, lif, rif, True)
                if direction & RTOL:
                    run_test(test, lif, rif, False)

def fetch_results():
    run_cmd('scp root@%s:%s/* %s/' % (remote_host, resdir, resdir))

if __name__ == '__main__':
    # parse args
    opts, args = getopt.getopt(sys.argv[1:], 'h:n:t:d:r:p:D:N:')
    for opt, arg in opts:
        if opt == '-h':
            remote_host = arg
            host_prefix_cmds['remote'] = 'ssh root@%s' % remote_host
        if opt == '-n':
            nicpairs = map(lambda s: s.split('-'), arg.split(','))
        if opt == '-t':
            tests = arg.split(",")
        if opt == '-d':
            testdir = arg
        if opt == '-r':
            resdir = arg
        if opt == '-p':
            priv_args = arg.split(",")
        if opt == '-D':
            direction = int(arg)
        if opt == '-N':
            nr_runs = int(arg)

    sanity_check()
    setup_hosts()
    init_hosts()
    start_tests()
    fetch_results()
