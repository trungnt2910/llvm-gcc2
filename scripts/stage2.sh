#!/bin/bash
set -e

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

GCC2_LIBRARY_PATH="$SCRIPT_DIR/gcc2/usr/lib/gcc-lib/i486-linux-gnu/2.95.4"

STAGE1_C_COMPILER="$(realpath "build_stage1_install/bin/clang")"
STAGE1_CXX_COMPILER="$(realpath "build_stage1_install/bin/clang++")"
STAGE1_ASM_COMPILER="$(realpath "build_stage1_install/bin/clang")"

mkdir -p build_stage2_install

if [ ! -f "build_stage2_install/lib/libc++.so" ]; then
    # Stage 2 Clang needs a modern C++ library with GCC2 ABI.
    #
    # We cannot build libcxx as part of stage 1 since
    # stage 1 targets the host's x86_64/Itanium environment.
    #
    # We cannot build libcxx along with stage 2 using
    # -DLLVM_ENABLE_RUNTIMES because that would be done **after**
    # Clang is built.
    #
    # Therefore, for stage 2, we manually build libcxx before
    # building Clang and point the stage 2 configuration to it.
    mkdir -p build_stage2_libcxx
    pushd build_stage2_libcxx

    STAGE2_LIBCXX_CFLAGS="                                          \
        --target=i486-linux-gnu                                     \
        -fc++-abi=gcc2                                              \
        -no-pie -fPIC                                               \
        -nodefaultlibs -nostdlib++ -nostdinc++                      \
        -lc                                                         \
        -L$GCC2_LIBRARY_PATH                                        \
        -Wl,--no-eh-frame-hdr                                       \
        -Wno-unused-command-line-argument                           \
    "

    cmake -G Ninja                                                  \
        -DCMAKE_BUILD_TYPE="Release"                                \
        -DCMAKE_SYSTEM_NAME="Linux"                                 \
        -DCMAKE_INSTALL_PREFIX=../build_stage2_install              \
        -DCMAKE_C_COMPILER="$STAGE1_C_COMPILER"                     \
        -DCMAKE_CXX_COMPILER="$STAGE1_CXX_COMPILER"                 \
        -DCMAKE_CXX_FLAGS="$STAGE2_LIBCXX_CFLAGS"                   \
        -DCMAKE_C_FLAGS="$STAGE2_LIBCXX_CFLAGS"                     \
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

mkdir build_stage2
pushd build_stage2

STAGE2_LIB="$(realpath ../build_stage2_install/lib)"
STAGE2_INCLUDE="$(realpath ../build_stage2_install/include)"

STAGE2_CFLAGS="                                                 \
    -fc++-abi=gcc2                                              \
    -no-pie -fPIC                                               \
    -nostdlib++ -nostdinc++                                     \
    -lc++ -lstdc++ -lgcc -lc                                    \
    -L$STAGE2_LIB                                               \
    -isystem $STAGE2_INCLUDE/c++/v1                             \
    -L$GCC2_LIBRARY_PATH                                        \
    -Wl,--no-eh-frame-hdr                                       \
    -Wno-unused-command-line-argument                           \
"

cmake -G Ninja                                                  \
    -DCMAKE_BUILD_TYPE="Release"                                \
    -DCMAKE_SYSTEM_NAME="Linux"                                 \
    -DCMAKE_INSTALL_PREFIX=../build_stage2_install              \
    -DCMAKE_C_COMPILER="$STAGE1_C_COMPILER"                     \
    -DCMAKE_CXX_COMPILER="$STAGE1_CXX_COMPILER"                 \
    -DCMAKE_ASM_COMPILER="$STAGE1_ASM_COMPILER"                 \
    -DCMAKE_CXX_FLAGS="$STAGE2_CFLAGS"                          \
    -DCMAKE_C_FLAGS="$STAGE2_CFLAGS"                            \
    -DCMAKE_C_COMPILER_TARGET="i486-linux-gnu"                  \
    -DCMAKE_CXX_COMPILER_TARGET="i486-linux-gnu"                \
    -DLLVM_ENABLE_PROJECTS="clang"                              \
    -DLLVM_ENABLE_ASSERTIONS=ON                                 \
    -DLLVM_ENABLE_LIBCXX=ON                                     \
    -DLLVM_INCLUDE_TESTS=OFF                                    \
    -DLLVM_PARALLEL_LINK_JOBS=1                                 \
    -DCLANG_INCLUDE_TESTS=ON                                    \
    ../llvm

ninja install

popd
