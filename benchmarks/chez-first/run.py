#!/usr/bin/env python3
"""Bounded existing-port modes on actual bundled applications and Shen SOR."""
import argparse,csv,hashlib,json,os,platform,re,selectors,shutil,struct,subprocess,time
from datetime import datetime,timezone
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];OWN=ROOT/'benchmarks/chez-first';WORK=ROOT/'.work/chez-first/modes';BASE=ROOT/'.work/chez-first/baseline'
MODES=('dynamic','compatible','sealed','app','app-wpo');APPS=('interpreter','cminus','numeric');DEADLINE=None
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def dump(p,v):Path(p).write_text(json.dumps(v,indent=2,sort_keys=True,allow_nan=False)+'\n')
def remain(cap):
 seconds=DEADLINE-time.monotonic()
 if seconds<=0:raise TimeoutError('180s aggregate budget exhausted')
 return min(cap,seconds)
def identities():
 manifest=BASE/'manifest.json';data=json.loads(manifest.read_text())
 runtime=BASE/'source/_build/bin/shen-scheme';paths=[manifest,runtime]
 assert data['upstream_kernel_commit'].startswith('ec16a9f') and data['chez']=='10.3.0'
 assert data['optimize_level']==2 and data['debug_level']==0
 snapshot=BASE/'source'
 for group in ('artifacts','generated_scheme','tracked_source_hashes'):
  for rel,h in data.get(group,{}).items():
   p=snapshot/rel;assert sha(p)==h,(group,rel);paths.append(p)
 for rel,h in dict(data['kernel_kl'],**data.get('generated_port_kl',{})).items():
  p=snapshot/'kl'/rel;assert sha(p)==h,rel;paths.append(p)
 paths+=list((BASE/'source/_build/lib/shen-scheme').rglob('*'))
 paths+=[ROOT/'shen-test-programs/interpreter.shen',ROOT/'shen-test-programs/c-minus.shen']
 paths+=[p for p in OWN.iterdir() if p.is_file() and p.name not in ('REPORT.md','SHA256SUMS.json')]
 paths=[p for p in paths if p.is_file()]
 return runtime,data,{str(p.relative_to(ROOT)):sha(p) for p in sorted(set(paths))}
def host():
 rows=subprocess.check_output(['ps','-axo','pid=,pcpu=,pmem=,comm='],text=True,timeout=5).splitlines()
 return dict(load_average=os.getloadavg(),process_names=sorted(rows,key=lambda s:float(s.split(None,3)[1]),reverse=True)[:10],note='Command names only; no OS CPU isolation.')
def numeric_reference(n=20,tolerance=.0001,cap=2000):
 g=[]
 for i in range(n):
  for j in range(n):
   x=j*1.0/(n-1);y=i*1.0/(n-1)
   g.append(x*x-y*y if i==0 or j==0 or i==n-1 or j==n-1 else 0.)
 def residual():
  result=0.
  for i in range(1,n-1):
   for j in range(1,n-1):
    k=i*n+j;value=((g[k-n]+g[k+n])+g[k-1])+g[k+1];d=value-4.*g[k]
    absolute=0.-d if d<0. else d
    result=absolute if absolute>result else result
  return result
 sweeps=0;r=residual()
 while r>tolerance and sweeps<cap:
  count=min(10,cap-sweeps)
  for _ in range(count):
   for i in range(1,n-1):
    for j in range(1,n-1):
     k=i*n+j;neighbors=((g[k-n]+g[k+n])+g[k-1])+g[k+1]
     g[k]=.3125*neighbors+-.25*g[k]
  sweeps+=count;r=residual()
 assert r<=tolerance
 assert max(abs(g[i*n+j]-((j/(n-1))**2-(i/(n-1))**2)) for i in range(n) for j in range(n))<.01
 return g,sweeps,r

def prepare_cell(out,app):
 out.mkdir(parents=True)
 actual=[] if app=='numeric' else ['shen-test-programs/'+('interpreter.shen' if app=='interpreter' else 'c-minus.shen')]
 main='benchmarks/chez-first/'+app+'-main.shen';sources=actual+[main]
 module_dir=out/'modules';module_dir.mkdir()
 # Module declarations reference unchanged relative source paths; their bytes
 # are retained and hashed. The generated cache/root is inside this owned cell.
 def descriptor(name,files,mode='compatible',requires=()):
  return '(shen.module (version 1) (name '+name+') '+('(requires '+' '.join(requires)+') ' if requires else '')+'(sources tc- '+' '.join(json.dumps(os.path.relpath(ROOT/p,module_dir)) for p in files)+') (extension shen/scheme (mode '+mode+') (profile release) (metadata runtime compiletime)))\n'
 for mode in ('compatible','sealed'):
  (module_dir/(mode+'.shenmod')).write_text(descriptor('cf.whole.'+app,sources,mode))
 # Numeric has one main module; symbolic apps have original sources + wrapper
 # in an explicit dependency graph so bundling links across source boundaries.
 if actual:
  (module_dir/('cf.core.'+app+'.shenmod')).write_text(descriptor('cf.core.'+app,actual,'sealed'))
  apptext=descriptor('cf.app.'+app,[main],'sealed',['cf.core.'+app])
 else:apptext=descriptor('cf.app.'+app,[main],'sealed')
 (module_dir/('cf.app.'+app+'.shenmod')).write_text(apptext)
 g,sweeps,residual=numeric_reference();fixture=out/'numeric-reference.bin';fixture.write_bytes(struct.pack('<400d',*g))
 # A nontrivial complete parse: declaration + 30 assignments + return. Expected
 # full AST is independent of parser output, including every statement.
 statements='int x; '+''.join('x = (x + '+str(i)+'); ' for i in range(1,31))+'return x;'
 parser='main () { '+statements+' };'
 expected='(() (main () (compound (declare int (x)) '+''.join('(assign x (+ x '+str(i)+')) ' for i in range(1,31))+'(return x))))'
 cfg='(define cf-app '+json.dumps(app)+')\n'
 for name,value in [('cf-compatible',str(module_dir/'compatible.shenmod')),('cf-sealed',str(module_dir/'sealed.shenmod')),('cf-app-descriptor',str(module_dir/('cf.app.'+app+'.shenmod'))),('cf-module-dir',str(module_dir)),('cf-object',str(out/'application.so')),('cf-cache-dir',str(out/'app-cache'))]:
  cfg+='(define '+name+' '+json.dumps(value)+')\n'
 cfg+='(define cf-sources (list '+' '.join(json.dumps(x) for x in sources)+'))\n'
 cfg+='(define cf-reps '+str({'interpreter':100,'cminus':20,'numeric':1}[app])+')\n'
 cfg+='(define cf-parser-input (map string (string->list '+json.dumps(parser)+')))\n'
 cfg+="(define cf-parser-expected '"+expected+')\n'
 cfg+='(define cf-expected-sweeps '+str(sweeps)+')\n(define cf-expected-residual '+repr(residual)+')\n'
 cfg+='(define cf-expected-grid (let* ([p (open-file-input-port '+json.dumps(str(fixture))+')] [b (get-bytevector-all p)]) (close-port p) b))\n'
 (out/'config.ss').write_text(cfg)
 dump(out/'workload.json',dict(app=app,sources={p:sha(ROOT/p) for p in sources},parser_input=parser,parser_expected=expected,numeric=dict(n=20,sweeps=sweeps,residual=residual,fixture_sha256=sha(fixture))))
 return {str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()}
def invoke(runtime,out,app,mode,sample,action,measure):
 env=dict(os.environ,CF_CONFIG=str(out/'config.ss'),CF_MODE=mode,CF_MEASURE='1' if measure else '0',CF_SAMPLE=str(sample),CF_ACTION=action,CF_OUTPUT=str(out/(action+'.csv')))
 cmd=[str(runtime),'script','benchmarks/chez-first/entry.shen'];deadline=time.monotonic()+remain(120);tick=time.perf_counter_ns();ready=None;raw=bytearray()
 with (out/(action+'.stderr')).open('wb') as stderr:
  process=subprocess.Popen(cmd,cwd=ROOT,env=env,stdout=subprocess.PIPE,stderr=stderr);selector=selectors.DefaultSelector();selector.register(process.stdout,selectors.EVENT_READ)
  try:
   while selector.get_map():
    seconds=deadline-time.monotonic()
    if seconds<=0:raise subprocess.TimeoutExpired(cmd,120)
    for key,_ in selector.select(min(seconds,1)):
     block=os.read(key.fileobj.fileno(),65536)
     if not block:selector.unregister(key.fileobj);continue
     raw.extend(block)
     if len(raw)>1048576:raise RuntimeError('stdout limit1MiB')
     if ready is None and b'CF_READY ' in raw and b'\n' in raw[raw.index(b'CF_READY '):]:ready=time.perf_counter_ns()-tick
   code=process.wait(timeout=max(.001,deadline-time.monotonic()))
  except Exception:process.kill();process.wait();raise
  finally:selector.close();(out/(action+'.stdout')).write_bytes(raw)
 text=raw.decode(errors='replace');marker='CF_BUILD PASS' if action=='build' else 'CF_VALIDATION PASS'
 if code or marker not in text:raise RuntimeError(f'{app}/{mode}/{action} failed {code}: '+text+' '+(out/(action+'.stderr')).read_text())
 bootstrap=re.findall(r'^CF_BOOTSTRAP cpu_ns=(\d+) allocated_bytes=(\d+) gc_count=(\d+) gc_cpu_ns=(\d+)$',text,re.M)
 assert len(bootstrap)==1,'missing/duplicate bootstrap metrics'
 receipt=dict(command=cmd,action=action,app=app,mode=mode,sample=sample,returncode=code,bootstrap_to_ready_wall_ns=ready,total_process_wall_ns=time.perf_counter_ns()-tick,bootstrap_cpu_ns=int(bootstrap[0][0]),bootstrap_allocated_bytes=int(bootstrap[0][1]),bootstrap_gc_count=int(bootstrap[0][2]),bootstrap_gc_cpu_ns=int(bootstrap[0][3]))
 dump(out/(action+'-process.json'),receipt);return receipt

def main():
 global DEADLINE
 p=argparse.ArgumentParser();p.add_argument('action',choices=('validate','measure'));p.add_argument('--cpu-granted',action='store_true');p.add_argument('--output',required=True);p.add_argument('--apps',nargs='+',choices=APPS,default=APPS);p.add_argument('--modes',nargs='+',choices=MODES,default=MODES);a=p.parse_args()
 measure=a.action=='measure'
 if measure and not a.cpu_granted:p.error('parent serialCPU grant required')
 DEADLINE=time.monotonic()+180;runtime,baseline,before=identities();out=ROOT/a.output
 if not out.is_relative_to(WORK):p.error('output must be inside .work/chez-first/modes/')
 out.mkdir(parents=True,exist_ok=False);dump(out/'started.json',dict(created_utc=datetime.now(timezone.utc).isoformat(),measurement=measure,identities=before,baseline=baseline,host=platform.platform()));dump(out/'host-before.json',host())
 rows=[];processes=[]
 try:
  for sample in range(5 if measure else 1):
   rotation=sample%len(a.modes);modes=a.modes[rotation:]+a.modes[:rotation]
   apps=list(a.apps);ar=sample%len(apps);apps=apps[ar:]+apps[:ar]
   for app in apps:
    for mode in modes:
     cell=out/f'sample-{sample}'/app/mode;generated=prepare_cell(cell,app)
     if mode!='dynamic':
      processes.append(invoke(runtime,cell,app,mode,sample,'build',measure))
      assert (cell/'application.so').is_file(),'missing native object'
     compiled={str(p.relative_to(cell)):sha(p) for p in cell.rglob('*') if p.is_file() and (p.suffix in ('.so','.wpo','.sls','.scm') or p.name.endswith('build-result.ss'))}
     processes.append(invoke(runtime,cell,app,mode,sample,'run',measure))
     for rel,h in generated.items():assert sha(cell/rel)==h,'fixture/config drift'
     for rel,h in compiled.items():assert sha(cell/rel)==h,'compiled artifact drift'
     dump(cell/'compiled-artifacts.json',compiled)
     if measure:
      cellrows=[]
      for action in (('run',) if mode=='dynamic' else ('build','run')):
       rs=list(csv.DictReader((cell/(action+'.csv')).open()));expected={'load','first','repeated'} if action=='run' else {'artifact-build'}
       assert {r['phase'] for r in rs}==expected and len(rs)==len(expected)
       for row in rs:
        assert row['app']==app and row['mode']==mode and int(row['sample'])==sample
        assert int(row['reps'])==({'interpreter':100,'cminus':20,'numeric':1}[app] if row['phase']=='repeated' else 1)
        for key in ('wall_ns','cpu_ns','allocated_bytes','gc_count','gc_cpu_ns'):assert int(row[key])>=0
       cellrows+=rs
      rows+=cellrows
     print(sample,app,mode,'PASS',flush=True)
  _,_,after=identities();assert before==after,'source/runtime drift'
  dump(out/'host-after.json',host());dump(out/'processes.json',processes)
  if measure:
   with (out/'all.csv').open('w',newline='') as stream:
    writer=csv.DictWriter(stream,fieldnames=rows[0].keys());writer.writeheader();writer.writerows(rows)
  dump(out/'metadata.json',dict(validation='PASS',samples=5 if measure else 1,rows=len(rows),identities=before,processes=processes,contract='Immutable releaseopt2 runtime; each artifact built in a fresh process, loaded/called in another fresh process. Dynamic load includes source parse/expansion/compilation/evaluation and initializers. Native build is source analysis+lowering+Chez compile+artifact output; runtime load+metadata/effects separate. Repeated application requests include input/result construction and true Chez allocation/GC.',artifact_sha256={str(p.relative_to(out)):sha(p) for p in out.rglob('*') if p.is_file()}))
 except Exception as e:dump(out/'rejected.json',dict(error=str(e),processes=processes));raise
if __name__=='__main__':main()
