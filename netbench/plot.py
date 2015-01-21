#!/usr/bin/env python

import sys
import os
import getopt
import glob
import re
import matplotlib.pyplot as plt
from common import *

test = None
nicpairs = None
resdir = None
kinds = None
postfix = None

def matched_values(pat, string):
    p = pat.search(string)
    if p == None:
        print >>sys.stderr, "Error: failed to parse %s" % string
        sys.exit(-1)
    return p.groups()

nfnewnic_pps_pat = re.compile(r'(\d+\.\d+) pps')
def nfnewnic_pps(string):
    results = nfnewnic_pps_pat.findall(string)
    return sum(map(float, results)) / float(len(results))

netmap_pps_pat = re.compile(r'Speed: (\d+\.\d+) ([MK])pps')
def netmap_pps(string):
    total_pps = 0.0
    results = netmap_pps_pat.findall(string)
    for pps, mag in results:
        total_pps += float(pps) * 1000 if mag == 'K' else float(pps) * 1000000
    return total_pps / float(len(results))

pps_func = {
        'nfnewnic': nfnewnic_pps,
        'ixgbe': netmap_pps,
}
def user_get_thput(nic, kind, out_files):
    pktlen_pat = re.compile(r'(\d+)_rx')
    t = {}
    for fn in out_files:
        pktlen = int(matched_values(pktlen_pat, fn)[0])
        pps = pps_func[nic](open(fn).read())
        if kind == 'pps':
            thput = pps / 1000
            unit = 'Kpps'
        elif kind == 'bw':
            thput = (pktlen * 8.0 * pps) * 1e-9
            unit = 'Gbps'
        elif kind == 'rawbw':
            # 20B framing(12B IFG + 8B Preemble) + 4B CRC
            thput = ((pktlen + 24) * 8.0 * pps) * 1e-9
            unit = 'Gbps'
        else:
            print >>sys.stderr, "Error: invalid throughput kind (valid=pps, bw, rawbw)"
            sys.exit(-1)
        t[pktlen] = thput
    return unit, t

avail_kinds = {
        'user': ('pps', 'bw', 'rawbw')
}
ylims = {
        'pps': [0, 15500],
        'bw': [0, 10],
        'rawbw': [0, 10.5]
}

def user_plot():
    pcigen_pat = re.compile(r'G(\d)')
    styles = ('bo-', 'cs--', 'k<-', 'rv--', 'g^-')
    global kinds
    if kinds == None:
        kinds = avail_kinds[test]
    for kind in kinds:
        fig, ax = plt.subplots()
        ax.set_xlabel('Packet size (Bytes)')
        for i, nicpair in enumerate(nicpairs):
            out_files = glob.glob('%s/%s_%s*_rx.out' % (resdir, test, nicpair))
            if len(out_files) == 0:
                print >>sys.stderr, "Error: failed to find %s in %s" % (nicpair, resdir)
                sys.exit(-1)
            label = nic = get_nic_name(nicpair)
            gens = pcigen_pat.findall(nicpair)
            if gens != None:
                label = nic + ' (Gen' + gens[0] + '->Gen' + gens[1] + ')'
            unit, t = user_get_thput(nic, kind, out_files)
            x, y = zip(*sorted(t.items()))
            ax.set_ylim(ylims[kind])
            ax.grid(which='major')
            ax.plot(x, y, styles[i], markersize=10, lw=2, label=label)
        ax.set_ylabel(unit)
        ax.legend(loc='best')
        outfn = '%s_%s_%s%s.png' % (test, ','.join(nicpairs), kind, '_' + postfix if postfix else '')
        fig.savefig(outfn)
        print '%s is generated' % outfn

plotfunc = {
        'user': user_plot
}

def show_usage_and_exit():
    sys.stdout = sys.stderr
    print "%s -t <test> -d <resdir> -n <nicpair1[,nicpair2,...] [-k <metric kind1[,kind2,...]>] [-p <postfix of output>]" % sys.argv[0]
    print "\tavailable tests:", plotfunc.keys()
    print "\tnicpair: indicates [lr]-postfixed nicpair included in a result file (e.g., nf0G1l-nf0G1r)"
    print "\tkinds: test-dependent kinds of metrics as follows:"
    for t in avail_kinds:
        print "\t\t%s - %s" % (t, ' '.join(list(avail_kinds[t])))
    print "\tpostfix: appended to output plot file"
    sys.exit(-1)

def sanity_check():
    if test == None or resdir == None or nicpairs == None or nicpairs[0] == '':
        show_usage_and_exit()
    if kinds and not set(kinds).issubset(avail_kinds[test]):
        print >>sys.stderr, 'Error: one of %s kinds is not included in' % (','.join(kinds)), avail_kinds[test]
        sys.exit(-1)
    if not os.path.exists(resdir):
        print >>sys.stderr, 'Error: %s is not found' % resdir
        sys.exit(-1)

if __name__ == '__main__':
    # parse args
    opts, args = getopt.getopt(sys.argv[1:], 't:n:d:k:p:')
    for opt, arg in opts:
        if opt == '-t':
            test = arg
        if opt == '-n':
            nicpairs = arg.split(',')
        if opt == '-d':
            resdir = arg
        if opt == '-k':
            kinds = arg.split(',')
        if opt == '-N':
            postfix = arg
    sanity_check()
    plotfunc[test]()
