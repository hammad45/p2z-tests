#!/bin/bash

if [[ !( "${BASH_VERSINFO:-0}" > 4 \
         || ("${BASH_VERSINFO:-0}" == 4 && "${BASH_VERSINFO:-1}" > 2)\
       ) ]]
then
   echo "Need bash >= 4.3"
   exit 1
fi

shopt -s lastpipe   # e.g. https://unix.stackexchange.com/questions/136206/readarray-or-pipe-issue

# Direct renames A->B
renames="alpaka::mem::alloc::alloc alpaka::malloc
alpaka::mem::buf::alloc alpaka::allocBuf
alpaka::event::test alpaka::isComplete
alpaka::vec::cast alpaka::castVec
alpaka::vec::reverse alpaka::reverseVec
alpaka::vec::concat alpaka::concatVec
alpaka::atomic::op::Add alpaka::AtomicAdd
alpaka::atomic::op::Sub alpaka::AtomicSub
alpaka::atomic::op::Min alpaka::AtomicMin
alpaka::atomic::op::Max alpaka::AtomicMax
alpaka::atomic::op::Exch alpaka::AtomicExch
alpaka::atomic::op::Inc alpaka::AtomicInc
alpaka::atomic::op::Dec alpaka::AtomicDec
alpaka::atomic::op::And alpaka::AtomicAnd
alpaka::atomic::op::Or alpaka::AtomicOr
alpaka::atomic::op::Xor alpaka::AtomicXor
alpaka::atomic::op::Cas alpaka::AtomicCas
alpaka::mem::view::set alpaka::memset
alpaka::mem::view::copy alpaka::memcpy
alpaka::block::op::Count alpaka::BlockCount
alpaka::block::op::LogicalAnd alpaka::BlockAnd
alpaka::block::op::LogicalOr alpaka::BlockOr
alpaka::block::shared::st::allocVar alpaka::declareSharedVar
alpaka::block::shared::dyn::getMem::getMem alpaka::getDynSharedMem
alpaka::block::shared::st::freeMem alpaka::freeSharedVars"

# Namespaces to remove
namespaces="alpaka::dev
alpaka::pltf
alpaka::vec
alpaka::workdiv
alpaka::acc
alpaka::atomic::op
alpaka::atomic
alpaka::queue
alpaka::idx
alpaka::dim
alpaka::kernel
alpaka::wait
alpaka::mem
alpaka::offset
alpaka::elem
alpaka::intrinsic
alpaka::event
alpaka::time
alpaka::example
alpaka::alloc
alpaka::buf
alpaka::view
alpaka::block::shared::st
alpaka::block::shared::dyn
alpaka::block::shared
alpaka::block::sync
alpaka::block::op
alpaka::block"

join_by () { 
    local d=$1
    shift
    local f=$1
    shift
    printf %s "$f" "${@/#/$d}"
}

parse_and_add () {
    local -n rns=$1
    local -n nss=$2
    local IFS=$'\n'
    for ns in $nss
    do
        echo $ns | sed 's/::/\n/g' | readarray -t hier
        unset hier[-1]
        local new=$(join_by :: ${hier[@]})
        rns="${rns}"$'\n'"$ns:: $new::"
    done
}

search_and_replace () {
    local -n fname=$1
    local -n rns=$2
    local IFS=$'\n'

    for rn in ${rns}
    do
        IFS=' ' arr=(${rn})
        sed -i "s/${arr[0]}/${arr[1]}/g" ${fname}
    done
}

if [[ $# == 0 ]]
then
    echo "Provide filenames as arguments"
    echo
    echo "Suggestion:"
    echo "find . \\( -name '*.cpp' -o -name '*.hpp' \\) -exec $0 {} \;"
fi

parse_and_add renames namespaces

for f in $@
do
    echo $f
    search_and_replace f renames
done
