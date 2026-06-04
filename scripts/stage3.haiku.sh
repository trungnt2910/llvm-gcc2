#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

STAGE2_C_COMPILER="$(realpath "build_stage2_install/bin/clang")"
STAGE2_CXX_COMPILER="$(realpath "build_stage2_install/bin/clang++")"
STAGE2_ASM_COMPILER="$(realpath "build_stage2_install/bin/clang")"

GCC2_LIBRARY_PATH="\
    $SCRIPT_DIR/boot/system/develop/tools/lib/gcc-lib/i586-pc-haiku/2.95.3-haiku-2017_07_20\
"

HAIKU_SYSTEM_HEADERS="                                              \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/bsd            \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/posix          \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/os             \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/os/kernel      \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/os/storage     \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/os/support     \
    -isystem $SCRIPT_DIR/boot/system/develop/headers                \
"

export LD_LIBRARY_PATH="$STAGE2_LIB:$SCRIPT_DIR/gcc2/usr/lib:$LD_LIBRARY_PATH"

pushd "$SCRIPT_DIR"
# TLS hack. Somehow Haiku hides ___tls_get_addr from GCC2 libroot.so.
echo "
#include <runtime_loader/runtime_loader.h>
struct tls_index {
	unsigned long ti_module;
	unsigned long ti_offset;
};
void *
___tls_get_addr(struct tls_index *ti)
{
	return __gRuntimeLoader->get_tls_address(ti->ti_module, ti->ti_offset);
}
" > tls.c
HAIKU_TLS_SYSTEM_HEADERS="
    -isystem $SCRIPT_DIR/boot/system/develop/headers/private                    \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/private/system             \
    -isystem $SCRIPT_DIR/boot/system/develop/headers/private/system/arch/x86    \
"
$STAGE2_CXX_COMPILER --target=i586-pc-haiku -c tls.c -o tls.o \
    $HAIKU_TLS_SYSTEM_HEADERS $HAIKU_SYSTEM_HEADERS
ar rcs libtls.a tls.o
rm tls.c tls.o
popd

mkdir -p build_stage3_install

if [ ! -f "build_stage3_install/lib/libc++.so" ]; then
    # Similar to stage 2, stage 3 needs a modern C++ library.
    # We cross-compile libcxx for Haiku using the stage 2 compiler.
    mkdir -p build_stage3_libcxx
    pushd build_stage3_libcxx

    # libroot refuses to give us ___tls_get_addr.
    #
    # Meanwhile, the LLVM build requires that symbol to be in
    # one of the **dynamic** libraries it links against.
    #
    # We therefore shove our libtls.a hack into libc++.so.
    #
    # TODO: Remove this hack after
    # https://review.haiku-os.org/c/haiku/+/11059.
    STAGE3_LIBCXX_CFLAGS="                                          \
        --target=i586-pc-haiku                                      \
        -fc++-abi=gcc2                                              \
        -fno-vtable-thunks                                          \
        -no-pie -fPIC                                               \
        -nodefaultlibs -nostdlib++ -nostdinc++                      \
        -lroot                                                      \
        -Wl,--whole-archive                                         \
            $SCRIPT_DIR/libtls.a                                    \
        -Wl,--no-whole-archive                                      \
        --sysroot="$SCRIPT_DIR/boot"                                \
        -fuse-ld=bfd                                                \
        -Wl,--no-eh-frame-hdr                                       \
        -Wl,-m,elf_i386                                             \
        $HAIKU_SYSTEM_HEADERS                                       \
        -L$SCRIPT_DIR/boot/system/develop/lib                       \
        -B$SCRIPT_DIR/boot/system/develop/lib                       \
        -B$GCC2_LIBRARY_PATH                                        \
        -Wno-ignored-qualifiers                                     \
        -Wno-unused-command-line-argument                           \
    "

    cmake -G Ninja                                                  \
        -DCMAKE_BUILD_TYPE="Release"                                \
        -DCMAKE_SYSTEM_NAME="Haiku"                                 \
        -DCMAKE_SYSROOT="$SCRIPT_DIR/boot"                          \
        -DCMAKE_INSTALL_PREFIX=../build_stage3_install              \
        -DCMAKE_C_COMPILER="$STAGE2_C_COMPILER"                     \
        -DCMAKE_CXX_COMPILER="$STAGE2_CXX_COMPILER"                 \
        -DCMAKE_CXX_FLAGS="$STAGE3_LIBCXX_CFLAGS"                   \
        -DCMAKE_C_FLAGS="$STAGE3_LIBCXX_CFLAGS"                     \
        -DPython3_EXECUTABLE="$(which python3)"                     \
        -DLIBCXX_CXX_ABI="gcc2"                                     \
        -DLIBCXX_CXX_ABI_LIBRARY_PATH="$GCC2_LIBRARY_PATH"          \
        -DLIBCXX_ABI_FORCE_GCC2=ON                                  \
        -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF                       \
        -DLIBCXX_ENABLE_NEW_DELETE_DEFINITIONS=ON                   \
        ../libcxx

    ninja install

    popd
fi

mkdir build_stage3
pushd build_stage3

STAGE3_LIB="$(realpath ../build_stage3_install/lib)"
STAGE3_INCLUDE="$(realpath ../build_stage3_install/include)"

# Be ABSOLUTELY sure that libc++ is linked before libroot.
# Otherwise, libroot will literally clog our std::clog symbol.
STAGE3_CFLAGS="                                                 \
    -fc++-abi=gcc2                                              \
    -fno-vtable-thunks                                          \
    -no-pie -fPIC                                               \
    -nodefaultlibs -nostdlib++ -nostdinc++                      \
    -lc++ -lroot                                                \
    --sysroot="$SCRIPT_DIR/boot"                                \
    -fuse-ld=bfd                                                \
    -Wl,--no-eh-frame-hdr                                       \
    -Wl,-m,elf_i386                                             \
    -L$STAGE3_LIB                                               \
    -isystem $STAGE3_INCLUDE/c++/v1                             \
    $HAIKU_SYSTEM_HEADERS                                       \
    -L$SCRIPT_DIR/boot/system/develop/lib                       \
    -B$SCRIPT_DIR/boot/system/develop/lib                       \
    -B$GCC2_LIBRARY_PATH                                        \
    -Wno-unused-command-line-argument                           \
"

cmake -G Ninja                                                  \
    -DCMAKE_BUILD_TYPE="Release"                                \
    -DCMAKE_SYSTEM_NAME="Haiku"                                 \
    -DCMAKE_SYSROOT="$SCRIPT_DIR/boot"                          \
    -DCMAKE_INSTALL_PREFIX=../build_stage3_install              \
    -DCMAKE_C_COMPILER="$STAGE2_C_COMPILER"                     \
    -DCMAKE_CXX_COMPILER="$STAGE2_CXX_COMPILER"                 \
    -DCMAKE_ASM_COMPILER="$STAGE2_ASM_COMPILER"                 \
    -DCMAKE_CXX_FLAGS="$STAGE3_CFLAGS"                          \
    -DCMAKE_C_FLAGS="$STAGE3_CFLAGS"                            \
    -DCMAKE_C_COMPILER_TARGET="i586-pc-haiku"                   \
    -DCMAKE_CXX_COMPILER_TARGET="i586-pc-haiku"                 \
    -DLLVM_ENABLE_PROJECTS="clang"                              \
    -DLLVM_ENABLE_ASSERTIONS=OFF                                \
    -DLLVM_ENABLE_LIBCXX=ON                                     \
    -DLLVM_INCLUDE_TESTS=OFF                                    \
    -DLLVM_PARALLEL_LINK_JOBS=1                                 \
    ../llvm

ninja install

popd
