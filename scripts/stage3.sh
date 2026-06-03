#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

GCC2_LIBRARY_PATH="$SCRIPT_DIR/gcc2/usr/lib/gcc-lib/i486-linux-gnu/2.95.4"

STAGE2_C_COMPILER="$(realpath "build_stage2_install/bin/clang")"
STAGE2_CXX_COMPILER="$(realpath "build_stage2_install/bin/clang++")"
STAGE2_ASM_COMPILER="$(realpath "build_stage2_install/bin/clang")"
STAGE2_LIB="$(realpath build_stage2_install/lib)"
STAGE2_INCLUDE="$(realpath build_stage2_install/include)"

export LD_LIBRARY_PATH="$STAGE2_LIB:$SCRIPT_DIR/gcc2/usr/lib:$LD_LIBRARY_PATH"

mkdir -p build_stage3_install

mkdir build_stage3
pushd build_stage3

STAGE3_CFLAGS="                                                 \
    -fc++-abi=gcc2                                              \
    -no-pie -fPIC                                               \
    -nostdinc++                                                 \
    -lstdc++                                                    \
    -L$STAGE2_LIB                                               \
    -isystem $STAGE2_INCLUDE/c++/v1                             \
    -L$GCC2_LIBRARY_PATH                                        \
    -Wl,--no-eh-frame-hdr                                       \
    -Wno-unused-command-line-argument                           \
"

STAGE3_LIBCXX_CFLAGS=$(
    echo "                                                          \
        -fc++-abi=gcc2                                              \
        -no-pie  -fPIC                                              \
        -nostdinc++                                                 \
        -L$GCC2_LIBRARY_PATH                                        \
        -Wl,--no-eh-frame-hdr                                       \
        -Wno-unused-command-line-argument                           \
    " | xargs | tr ' ' ';'
)

cmake -G Ninja                                                          \
    -DCMAKE_BUILD_TYPE="Release"                                        \
    -DCMAKE_SYSTEM_NAME="Linux"                                         \
    -DCMAKE_INSTALL_PREFIX=../build_stage3_install                      \
    -DCMAKE_C_COMPILER="$STAGE2_C_COMPILER"                             \
    -DCMAKE_CXX_COMPILER="$STAGE2_CXX_COMPILER"                         \
    -DCMAKE_ASM_COMPILER="$STAGE2_ASM_COMPILER"                         \
    -DCMAKE_CXX_FLAGS="$STAGE3_CFLAGS"                                  \
    -DCMAKE_C_FLAGS="$STAGE3_CFLAGS"                                    \
    -DCMAKE_C_COMPILER_TARGET="i486-linux-gnu"                          \
    -DCMAKE_CXX_COMPILER_TARGET="i486-linux-gnu"                        \
    -DLLVM_ENABLE_PROJECTS="clang"                                      \
    -DLLVM_ENABLE_RUNTIMES="libcxx"                                     \
    -DLLVM_ENABLE_ASSERTIONS=OFF                                        \
    -DLLVM_ENABLE_LIBCXX=ON                                             \
    -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF                            \
    -DLLVM_INCLUDE_TESTS=OFF                                            \
    -DLLVM_PARALLEL_LINK_JOBS=1                                         \
    -DLLVM_DEFAULT_TARGET_TRIPLE="i486-linux-gnu"                       \
    -DCLANG_INCLUDE_TESTS=ON                                            \
    -DLIBCXX_CXX_ABI="gcc2"                                             \
    -DLIBCXX_CXX_ABI_LIBRARY_PATH="$GCC2_LIBRARY_PATH"                  \
    -DLIBCXX_ADDITIONAL_COMPILE_FLAGS="$STAGE3_LIBCXX_CFLAGS"           \
    -DLIBCXX_ABI_FORCE_GCC2=ON                                          \
    -DLIBCXX_ENABLE_ABI_LINKER_SCRIPT=OFF                               \
    -DLIBCXX_ENABLE_NEW_DELETE_DEFINITIONS=ON                           \
    ../llvm

ninja install

popd
