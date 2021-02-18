#!/bin/bash

module load intel/20
module load cuda/11
export BOOSTROOT=$HOME/soft/hep
export PATH=$HOME/soft/hep/bin:$PATH
export LD_LIBRARY_PATH=$HOME/soft/hep/lib:$LD_LIBRARY_PATH

make -C .. cleanall
nvcc --version
icc --version
compilers=("gcc" "icc" "pgi" "pgi" "gcc" "icc" "gcc"   "icc"   "nvcc"  "gcc"    "icc"    "nvcc"   "nvcc" "nvcc")
    modes=("omp" "omp" "omp" "acc" "tbb" "tbb" "eigen" "eigen" "eigen" "alpaka" "alpaka" "alpaka" "cuda" "cudav2")


for idx in "${!compilers[@]}";do
  compiler=${compilers[$idx]}
  mode=${modes[$idx]}
  echo ${compiler} and ${mode}
  
 # make -C .. COMPILER=${compiler} MODE=${mode} TUNEB=${btune} TUNETRK=${trktune} TUNEEVT=${event} NTHREADS=${nthread} clean
  make -C .. COMPILER=${compiler} MODE=${mode} 
done




