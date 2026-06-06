# llvm-gcc2

[![Discord Invite][2]][1]

Builds of the LLVM Toolchain with GCC 2.95-compatible ABI.

## Overview

This repository contains scripts that perform a 3-stage bootstrap of Clang from the
[llvm-gcc2 branch](https://github.com/trungnt2910/llvm-project/tree/dev/trungnt2910/llvm-gcc2).

### Stage 1

Stage 1 builds a toolchain targeting the host machine (i.e. `x86_64-linux`) with the ability to
generate GCC 2.95-compatible binaries.

Stage 1 acts as an initial guard, verifying that our source code builds correctly. CodeGen tests
will also be run against the stage 1 toolchain.

Stage 1 is built with assertions on, allowing the GCC2 backend to be tested in the following steps.

### Stage 2

Stage 2 first builds a modern `libcxx` that is compatible with the GCC 2.95 ABI using the stage 1
toolchain. Then, with this library, a full toolchain targeting `i486-linux` is built.

Stage 2 ensures that our CodeGen backend built in stage 1 behaves correctly at runtime.

Stage 2 is also built with assertions on.

### Stage 3

Stage 3 builds the full Clang project and the `libcxx` library in one go.

Stage 3 ensures that the code _generated_ by stage 1 (i.e. stage 2) behaves correctly.

Stage 3 is intended for release and built with assertions _off_.

## Builds

You can check the latest build for x86 Linux and Haiku on the
[Releases](https://github.com/trungnt2910/llvm-gcc2/releases) tab.

## Community

This repo is a part of [Project Reality][1].

Need help using this project? Join me on [Discord][1], and let's find a solution together.

[1]: https://reality.trungnt2910.com/discord
[2]: https://img.shields.io/discord/1185622479436251227?logo=discord&logoColor=white&label=Discord&labelColor=%235865F2
