#!/bin/bash
set -euo pipefail

TARGET_DIR="./gcc2"
mkdir -p "$TARGET_DIR"

URLS=(
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/gcc-2.95_2.95.4-27_i386.deb"
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/libstdc%2B%2B2.10-dev_2.95.4-27_i386.deb"
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/libstdc%2B%2B2.10-glibc2.2_2.95.4-27_i386.deb"
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/libg%2B%2B2.8.1.3-glibc2.2_2.95.4-27_i386.deb"
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/g%2B%2B-2.95_2.95.4-27_i386.deb"
    "https://snapshot.debian.org/archive/debian/20070204T000000Z/pool/main/g/gcc-2.95/cpp-2.95_2.95.4-27_i386.deb"
)

for url in "${URLS[@]}"; do
    echo "Processing: $url"
    curl -sL "$url" | dpkg-deb --extract /dev/stdin "$TARGET_DIR"
done

echo "All packages extracted successfully inside '$(realpath $TARGET_DIR)'."
