#!/bin/bash
set -eu

export ANDROID_BUILD_TOP="$PWD"

# Older kernels export sched_param, which Bionic provides in <sched.h>.
# Keep sched_attr and the remaining kernel ABI definitions intact.
sched_types="$1/usr/include/linux/sched/types.h"
if [ -f "$sched_types" ]; then
    sed -i '/^struct sched_param[[:space:]]*{/,/^};/d' "$sched_types"
fi

./bionic/libc/kernel/tools/clean_header.py -u \
    "$1/usr/include/asm/signal.h" \
    "$1/usr/include/asm-generic/signal.h"
