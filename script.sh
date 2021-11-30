#!/bin/sh
HARDWARE_COUNTER="PAPI_NATIVE_FP_ARITH_INST_RETIRED:512B_PACKED_SINGLE_TBB"
HARDWARE_COUNTER1="PAPI_NATIVE_FP_ARITH_INST_RETIRED_512B_PACKED_SINGLE"
filename='Functions.txt'
n=1
while read line; do
   for i in 1
   do
      python3 script.py "/home/hammad/Desktop/Fall 2021/Research/Profile Files/40 Threads/p2z/$HARDWARE_COUNTER/$i/MULTI__${HARDWARE_COUNTER1}/" $line
      # python3 script.py 40_Threads/p2z/PAPI_NATIVE_FP_ARITH_INST_RETIRED:SCALAR_SINGLE/$i/MULTI__PAPI_NATIVE_FP_ARITH_INST_RETIRED_SCALAR_SINGLE $line
   done

   # for i in 0 1
   # do
   #    python3 script.py "/home/hammad/Desktop/Fall 2021/Research/Profile Files/40 Threads/p2z/${HARDWARE_COUNTER}_TBB/$i/MULTI__TIME/" $line
   #    # python3 script.py 40_Threads/p2z/PAPI_NATIVE_FP_ARITH_INST_RETIRED:SCALAR_SINGLE_TBB/$i/MULTI__PAPI_NATIVE_FP_ARITH_INST_RETIRED_SCALAR_SINGLE $line
   # done

   # python3 box_plots.py Plots/Exclusive_Count_Data_${HARDWARE_COUNTER}_$line
   n=$((n+1))
done < $filename


