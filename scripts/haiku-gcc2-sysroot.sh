#!/bin/bash
set -e

# Target configuration
HAIKU_ARCH="x86_gcc2"
HAIKU_SYSPACKAGES="haiku haiku_devel"
HAIKU_PACKAGES="gcc"

# Mirrors and Endpoints
HAIKU_DEPOT_BASE_URL="https://depot.haiku-os.org/__api/v2/pkg/get-pkg"
HAIKU_HPKG_BASE_URL="https://eu.hpkg.haiku-os.org/haiku/master/$HAIKU_ARCH/current"
CURL_RETRY_COUNT="16"

# 1. Fetch the latest system hrev from the mirror index
echo "Fetching latest hrev version..."
HAIKU_SYSPACKAGES_HREV=$(curl --retry $CURL_RETRY_COUNT -Ls $HAIKU_HPKG_BASE_URL | sed -n 's/^.*version: "\([^"]*\)".*$/\1/p')

if [ -z "$HAIKU_SYSPACKAGES_HREV" ]; then
    echo "Error: Could not retrieve the latest hrev version." >&2
    exit 1
fi
echo "Latest hrev is: $HAIKU_SYSPACKAGES_HREV"

# 2. Download System Packages (haiku and haiku_devel) to current directory
echo "Downloading Haiku system packages..."
read -ra sys_array <<< "$HAIKU_SYSPACKAGES"
for package in "${sys_array[@]}"; do
    FILE_NAME="${package}-${HAIKU_SYSPACKAGES_HREV}-1-${HAIKU_ARCH}.hpkg"
    echo "Downloading $FILE_NAME..."

    curl --retry $CURL_RETRY_COUNT \
        -Lo "./$FILE_NAME" \
        "$HAIKU_HPKG_BASE_URL/packages/$FILE_NAME"
done

# 3. Download Port Packages (gcc) via depot API to current directory
echo "Querying and downloading port packages..."
read -ra pkg_array <<< "$HAIKU_PACKAGES"
for package in "${pkg_array[@]}"; do
    # Call Haiku Depot API to get the explicit download URL
    hpkgDownloadUrl="$(curl --retry $CURL_RETRY_COUNT -Ls --request POST \
        --data '{"name":"'"$package"'","repositorySourceCode":"haikuports_'$HAIKU_ARCH'","versionType":"LATEST","naturalLanguageCode":"en"}' \
        --header 'Content-Type:application/json' "$HAIKU_DEPOT_BASE_URL" | sed -n 's/^.*hpkgDownloadURL":"\([^"]*\)".*$/\1/p')"

    # Extract the full file name from the URL string
    hpkgFileName=$(basename "$hpkgDownloadUrl")

    echo "Downloading $hpkgFileName..."
    curl --retry $CURL_RETRY_COUNT -Lo "./$hpkgFileName" "$hpkgDownloadUrl"
done

# 4. Download host tools.
curl -sL $(curl -sL \
  https://raw.githubusercontent.com/haiku/haiku-toolchains-ubuntu/refs/heads/master/fetch.sh \
  | bash -s -- --hosttools --arch=x86_gcc2) > hosttools.zip
mkdir -p hosttools
unzip -q -o -d hosttools hosttools.zip
rm hosttools.zip
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$(pwd)/hosttools

# 5. Re-create and extract the sysroot.
rm -rf boot
mkdir -p boot/system
for file in *.hpkg; do
    echo "Extracting $file..."
    hosttools/package extract -C boot/system "$file"
done

# 6. Clean up downloaded packages and host tools.
rm -r *.hpkg
rm -rf hosttools

# 7. Hack for building with libstdc++.
ln -s libstdc++.r4.so boot/system/develop/lib/libstdc++.so

echo "Done."
