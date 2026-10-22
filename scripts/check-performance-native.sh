#!/bin/sh
# Run from the repository root. Build and load use separate fresh processes.
set -eu
shen=${1:-./_build/bin/shen-scheme}
mkdir -p _build/performance-native
"$shen" eval -q \
  -e '(eval-kl [scm.load "lib/performance/load.ss"])' \
  -e '(eval-kl [scm.performance-load "lib/performance"])' \
  -e '(shen-scheme.compile-module "examples/performance/native/arrays.shenmod" "_build/performance-native/arrays.so")'
"$shen" eval -q \
  -e '(eval-kl [scm.load "lib/performance/load.ss"])' \
  -e '(eval-kl [scm.performance-load "lib/performance"])' \
  -e '(shen-scheme.load-compiled "_build/performance-native/arrays.so")' \
  -e '(if (= (perf-example.native-array-demo 9) (perf.f64 2)) ok (error "native managed-array example failed"))'
echo 'PERFORMANCE_NATIVE PASS'
