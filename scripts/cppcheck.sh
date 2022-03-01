#!/bin/bash -eu

# echo PWD=$(pwd), CPPCHECK: $@

CPPCHECK_ARGS=(
    --enable=warning
    --inline-suppr
    #--cppcheck-build-dir=${PROJECT_BINARY_DIR}/analysis/cppcheck
    --quiet \
    --xml
    --xml-version=2
    --output-file=cppcheck_output.txt
    "$@"
)

#cppcheck ${CPPCHECK_ARGS[@]}

# -DZF_LOG_LEVEL=3
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/capdl/capdl-loader-app/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4runtime/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4runtime/include/mode/32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4runtime/include/arch/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4runtime/include/sel4_arch/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/kernel/libsel4/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/kernel/libsel4/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/kernel/libsel4/sel4_arch_include/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/kernel/libsel4/sel4_plat_include/imx6
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/kernel/libsel4/mode_include/32
# -Ilibsel4/include
# -Ilibsel4/arch_include/arm
# -Ilibsel4/sel4_arch_include/aarch32
# -Ilibsel4/autoconf
# -Ikernel/gen_config
# -Ilibsel4/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libcpio/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4platsupport/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4platsupport/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4platsupport/plat_include/imx6
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4platsupport/mach_include/imx
# -Imusllibc/build-temp/stage/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4simple/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4simple/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libutils/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libutils/arch_include/arm
# -Iutil_libs/libutils/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4vka/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4vka/sel4_arch_include/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4vka/arch_include/arm
# -IseL4_libs/libsel4vka/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4debug/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4debug/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4debug/sel4_arch_include/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4vspace/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4vspace/arch_include/arm
# -IseL4_libs/libsel4utils/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libplatsupport/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libplatsupport/plat_include/imx6
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libplatsupport/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libplatsupport/mach_include/imx
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libplatsupport/sel4_arch_include/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libfdt/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libfdt/.
# -Iutil_libs/libplatsupport/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4simple-default/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4utils/include
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4utils/sel4_arch_include/aarch32
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4utils/arch_include/arm
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_util_libs/libelf/include
# -Icapdl/capdl-loader-app/gen_config
# -I/host/OS-SDK/pkg/sdk-sel4-camkes/libs/sel4_libs/libsel4muslcsys/include
# -IseL4_libs/libsel4muslcsys/gen_config
# -D__KERNEL_32__
# /host/OS-SDK/pkg/sdk-sel4-camkes/capdl/capdl-loader-app/src/main.c
#
