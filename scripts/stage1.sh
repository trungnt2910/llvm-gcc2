#!/bin/bash
set -e

mkdir build_stage1_install

mkdir build_stage1
pushd build_stage1

cmake -G Ninja                                      \
    -DCMAKE_BUILD_TYPE=Release                      \
    -DCMAKE_INSTALL_PREFIX=../build_stage1_install  \
    -DLLVM_ENABLE_PROJECTS="clang"                  \
    -DLLVM_ENABLE_ASSERTIONS=ON                     \
    -DLLVM_PARALLEL_LINK_JOBS=1                     \
    ../llvm

ninja install

popd
