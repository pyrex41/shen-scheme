#!/usr/bin/env python3
"""Read-only paired analysis; generated after the frozen timing cohort."""
import csv
import json
import statistics
import sys
from pathlib import Path

APPS = ('interpreter', 'cminus', 'numeric')
MODES = ('dynamic', 'compatible', 'sealed', 'app', 'app-wpo')
METRICS = ('cpu_ns', 'wall_ns', 'allocated_bytes', 'gc_count', 'gc_cpu_ns')

def spread(values):
    return dict(median=statistics.median(values), minimum=min(values), maximum=max(values), samples=values)

def main():
    root = Path(sys.argv[1])
    rows = list(csv.DictReader((root / 'all.csv').open()))
    table = {}
    for r in rows:
        key = (int(r['sample']), r['app'], r['mode'], r['phase'])
        assert key not in table
        table[key] = {m: int(r[m]) / int(r['reps']) for m in METRICS}
    expected = {(s,a,m,p) for s in range(5) for a in APPS for m in MODES
                for p in (('load','first','repeated') if m == 'dynamic' else ('artifact-build','load','first','repeated'))}
    assert set(table) == expected and len(rows) == 285
    processes = json.loads((root / 'processes.json').read_text())
    assert len(processes) == 135
    result = {'contract': 'Per-request normalized rows; paired ratios dynamic/native within each app and sample. Ratio >1 favors native. No zero-denominator ratio is fabricated.', 'apps': {}}
    for app in APPS:
        modes = result['apps'][app] = {}
        for mode in MODES:
            entry = modes[mode] = {'phases': {}, 'paired_dynamic_over_mode': {}}
            phases = ('load','first','repeated') if mode == 'dynamic' else ('artifact-build','load','first','repeated')
            for phase in phases:
                entry['phases'][phase] = {metric: spread([table[s,app,mode,phase][metric] for s in range(5)]) for metric in METRICS}
                if phase != 'artifact-build':
                    entry['paired_dynamic_over_mode'][phase] = {}
                    for metric in METRICS:
                        pairs = [(table[s,app,'dynamic',phase][metric],table[s,app,mode,phase][metric]) for s in range(5)]
                        ratios = [a/b for a,b in pairs if b != 0]
                        entry['paired_dynamic_over_mode'][phase][metric] = dict(ratios=spread(ratios) if ratios else None, native_faster=sum(b<a for a,b in pairs), native_equal=sum(b==a for a,b in pairs), denominator_nonzero=len(ratios))
            ps = [p for p in processes if p['app']==app and p['mode']==mode and p['action']=='run']
            entry['bootstrap'] = {metric: spread([p[metric] for p in ps]) for metric in ('bootstrap_to_ready_wall_ns','bootstrap_cpu_ns','bootstrap_allocated_bytes','bootstrap_gc_count','bootstrap_gc_cpu_ns')}
            # Cumulative measured-stage cost: artifact build (native only),
            # application load and N complete requests. EXCLUDES both process
            # bootstraps, which remain separately reported in process receipts.
            # Actual first plus N-1 times measured repeated-per-request. This is
            # an additive observed-stage model, not a newly timed end-to-end N.
            entry['additive_cost_model'] = {}
            for count in (1,10,100,1000):
                modeled = {}
                for metric in ('cpu_ns','wall_ns'):
                    vals=[]
                    for s in range(5):
                        total = table[s,app,mode,'load'][metric] + table[s,app,mode,'first'][metric] + (count-1)*table[s,app,mode,'repeated'][metric]
                        if mode != 'dynamic': total += table[s,app,mode,'artifact-build'][metric]
                        vals.append(total)
                    modeled[metric] = spread(vals)
                entry['additive_cost_model'][str(count)] = modeled
    (root / 'paired-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    for app, modes in result['apps'].items():
        print('\n'+app)
        for mode,e in modes.items():
            rep=e['phases']['repeated'];load=e['phases']['load'];build=e['phases'].get('artifact-build')
            ratio=e['paired_dynamic_over_mode']['repeated']['cpu_ns']
            print(mode, 'request_us', round(rep['cpu_ns']['median']/1000,3), round(rep['wall_ns']['median']/1000,3), 'bytes',rep['allocated_bytes']['median'], 'load_ms',round(load['cpu_ns']['median']/1e6,3), round(load['wall_ns']['median']/1e6,3), 'build_ms',None if not build else (round(build['cpu_ns']['median']/1e6,3),round(build['wall_ns']['median']/1e6,3)), 'cpu_speedup',ratio['ratios'], 'wins',ratio['native_faster'])

if __name__ == '__main__': main()
