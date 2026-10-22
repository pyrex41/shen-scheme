#!/usr/bin/env python3
"""Build the pinned macOS baseline using explicit local input paths.

Required inputs: --kernel-archive, --chez-cache, --bootstrap-archive.
--reference-kernel optionally checks the archive KL against an independent
23-file generated klambda directory. This parameterized recipe has not been
rerun for existing measurements. Their exact historical recipe and its hash
remain frozen in .work/chez-first/baseline/recipe.py and manifest.json.
"""
import argparse,hashlib,json,shutil,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BASE=ROOT/'.work/chez-first/baseline';SRC=BASE/'source';PIN='680e2e95ed9dd0ca6d2f688453efca2a37e50021'
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--kernel-archive',required=True,type=Path,
                    help='Pinned ShenOSKernel-43.1-ec16a9f.tar.gz')
parser.add_argument('--chez-cache',required=True,type=Path,
                    help='Chez cache directory containing csv10.3.0 and its extraction stamp')
parser.add_argument('--bootstrap-archive',required=True,type=Path,
                    help='Pinned shen-scheme-v0.26-macOS-bin.tar.gz')
parser.add_argument('--reference-kernel',type=Path,
                    help='Optional independent generated klambda directory')
args=parser.parse_args()
ARCHIVE=args.kernel_archive.expanduser().resolve()
CHEZ_CACHE=args.chez_cache.expanduser().resolve()
bootstrap_archive=args.bootstrap_archive.expanduser().resolve()
REFERENCE=args.reference_kernel.expanduser().resolve() if args.reference_kernel else None
EXPECTED='060066a8f84d9a2f7d41cb3b37b986a8d4653279752b739b5063cd648d9baacd'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
if SRC.exists():raise SystemExit('Refusing to overwrite immutable baseline source')
if sha(ARCHIVE)!=EXPECTED:raise SystemExit('Kernel archive SHA-256 mismatch')
if sha(bootstrap_archive)!='a9c321a286daf354dda8ab51eb2b191cbdc339c2087e4490488c88ce462f5dc6':
 raise SystemExit('Bootstrap archive SHA-256 mismatch')
if not (CHEZ_CACHE/'csv10.3.0/tarm64osx/bin/tarm64osx/scheme').is_file():
 raise SystemExit('Chez cache must contain the built 10.3.0 macOS arm64 executable')
if not (CHEZ_CACHE/'.csv10.3.0-d237d9874c6e8b0ccf7758daa8286a6e825528b13ce3b2bca56eb1f73cddbc2c.extracted').is_file():
 raise SystemExit('Chez cache extraction checksum stamp is missing')
BASE.mkdir(parents=True,exist_ok=True)
SRC.mkdir()
names=subprocess.check_output(['git','-C',str(ROOT),'ls-tree','-r','--name-only',PIN],text=True).splitlines()
for name in names:
 p=SRC/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(subprocess.check_output(['git','-C',str(ROOT),'show',f'{PIN}:{name}']))
# Preserve executable bits from the tree for checked-in shell test helpers.
for line in subprocess.check_output(['git','-C',str(ROOT),'ls-tree','-r',PIN],text=True).splitlines():
 metadata,name=line.split('\t');
 if metadata.startswith('100755'):(SRC/name).chmod(0o755)
with tarfile.open(ARCHIVE) as archive:archive.extractall(BASE/'kernel')
kernels=list((BASE/'kernel').glob('*/klambda'));assert len(kernels)==1;kernel=kernels[0]
assert len(list(kernel.glob('*.kl')))==23
for p in kernel.glob('*.kl'):
 if REFERENCE:assert p.read_bytes()==(REFERENCE/p.name).read_bytes(),p.name
 shutil.copyfile(p,SRC/'kl'/p.name)
shutil.copytree(CHEZ_CACHE,SRC/'_build/chez',symlinks=True)
# Chez symlinks are internal relative links; prohibit any escape to the cache.
for p in (SRC/'_build/chez').rglob('*'):
 if p.is_symlink():assert p.resolve().is_relative_to(SRC/'_build/chez'),p
assert sha(bootstrap_archive)=='a9c321a286daf354dda8ab51eb2b191cbdc339c2087e4490488c88ce462f5dc6'
with tarfile.open(bootstrap_archive) as archive:archive.extractall(SRC/'_build')
BOOTSTRAP=SRC/'_build/shen-scheme-v0.26-macOS-bin/bin/shen-scheme'
logs=BASE/'logs';logs.mkdir()
def run(args,name,cwd=SRC):
 with (logs/name).open('w') as log:subprocess.run(args,cwd=cwd,stdout=log,stderr=subprocess.STDOUT,check=True,timeout=120)
run(['make','precompile',f'SHEN={BOOTSTRAP}'],'precompile.log')
run(['make','SHEN_SCHEME_OPTIMIZE_LEVEL=2','SHEN_SCHEME_DEBUG_LEVEL=0','SHEN_SCHEME_INSPECTOR=false','SHEN_SCHEME_SOURCE_INFO=false'],'build.log')
exe=SRC/'_build/bin/shen-scheme'
run([str(exe),'--version'],'version.log')
run([str(exe),'script','runme.shen'],'kernel154.log',kernel.parent/'tests')
run(['make','test-native','test-native-examples','test-compiler','test-byte-string-boundaries','test-hush','test-repl-eof'],'focused-port.log')
# Port library tests regenerate sources. Rebuild coherent final baseline once.
run(['make','precompile',f'SHEN={exe}'],'final-precompile.log')
run(['make','SHEN_SCHEME_OPTIMIZE_LEVEL=2','SHEN_SCHEME_DEBUG_LEVEL=0','SHEN_SCHEME_INSPECTOR=false','SHEN_SCHEME_SOURCE_INFO=false'],'final-build.log')
run([str(exe),'script','runme.shen'],'final-kernel154.log',kernel.parent/'tests')
run([str(exe),'eval','-q','-e','(if (= (+ 1 2) 3) ok (error "baseline smoke failed"))'],'final-smoke.log')
for p in kernel.glob('*.kl'):assert p.read_bytes()==(SRC/'kl'/p.name).read_bytes()
m={'commit':PIN,'upstream_kernel_commit':'ec16a9fa4fc2e87e2aa336fb1ae30e8ac2266394','kernel_archive_sha256':EXPECTED,'chez':'10.3.0','optimize_level':2,'debug_level':0,'source_info':False,'inspector':False,'source_snapshot':str(SRC.relative_to(ROOT)),'executable':str(exe.relative_to(ROOT)),'tracked_source_hashes':{n:sha(SRC/n) for n in names},'kernel_kl':{p.name:sha(p) for p in kernel.glob('*.kl')},'generated_scheme':{str(p.relative_to(SRC)):sha(p) for p in [SRC/'shen-scheme.scm',SRC/'shen-scheme-runtime.ss',*sorted((SRC/'compiled').glob('*.scm'))]},'artifacts':{str(p.relative_to(SRC)):sha(p) for p in [exe,SRC/'_build/lib/shen-scheme/shen-scheme/runtime.so',SRC/'_build/lib/shen-scheme/petite.boot',SRC/'_build/lib/shen-scheme/scheme.boot']},'kernel_suite':{'passed':154,'failed':0},'focused_port_checks':'make test-native test-native-examples test-compiler test-byte-string-boundaries test-hush test-repl-eof','bootstrap_executable_sha256':sha(BOOTSTRAP),'chez_cache_origin':str(CHEZ_CACHE),'reference_kernel':str(REFERENCE) if REFERENCE else None,'version_output':(logs/'version.log').read_text().strip()}
import re
for log in ['kernel154.log','final-kernel154.log']:
 text=(logs/log).read_text();assert re.findall(r'passed \.\.\.\s+(\d+)',text)[-1]=='154';assert not any(map(int,re.findall(r'failed \.\.\.\s+(\d+)',text)))
m['generated_port_kl']={p.name:sha(p) for p in (SRC/'kl').glob('*.kl') if p.name not in m['kernel_kl']}
m['recipe_sha256']=sha(ROOT/'scripts/chez-first-prepare.py')
m['bootstrap_archive_sha256']='a9c321a286daf354dda8ab51eb2b191cbdc339c2087e4490488c88ce462f5dc6'
(BASE/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
print(exe)
