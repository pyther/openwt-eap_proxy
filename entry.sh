#!/bin/sh
BUILD_DIR='build'
mkdir "$BUILD_DIR"

# UPDATE ME! x86_64 release
# Release Page: https://downloads.openwrt.org/releases/
SDK_URL=https://archive.openwrt.org/releases/22.03.2/targets/x86/64/openwrt-sdk-22.03.2-x86-64_gcc-11.2.0_musl.Linux-x86_64.tar.xz
SDK_SUM=d5718b743004f6b16996c439f35833c89e1a38b056c599b2917f22b24dc467f8

SDK_FILE=$(basename $SDK_URL)

download() {
    echo "Downloading SDK"
    wget $SDK_URL || exit 1
}

setup() {
    # Download file, if it does not exist
    [ -f $SDK_FILE ] || download

    # check that download tar matches expected checksum
    if [ "$(sha256sum $SDK_FILE | awk '{print $1}')" != $SDK_SUM ]; then
       echo "$SDK_FILE does not match sha256 signature"
       exit 1
    fi

    echo "Extracting SDK"
    tar xf $SDK_FILE
    
    echo "Updating and Installing openwrt feeds"
    cd $(basename $SDK_FILE .tar.xz)
    
    cp feeds.conf.default feeds.conf
    echo "src-link pyther /src" >> feeds.conf
    ./scripts/feeds update -a
    ./scripts/feeds install -a

    echo "Generating config and disabling package signing"
    make defconfig
    sed -i 's/CONFIG_SIGNED_PACKAGES=y/CONFIG_SIGNED_PACKAGES=n/' .config
}

if [ ! -d $BUILD_DIR ]; then
   echo "$BUILD_DIR does not exist, did you remember to bind mount it?"
   exit 1
fi

cd $BUILD_DIR

# Check if Directory exists
if [ -d $(basename $SDK_FILE .tar.xz) ]; then
   echo "WARNING: $(basename $SDK_FILE .tar.xz) exists! Skipping setup!"
   cd $(basename $SDK_FILE .tar.xz) || exit 1
else
   setup
fi

PKG=$1
if [ ! -z $PKG ]; then
   echo "$PKG: Download"
   make package/$PKG/download V=s || exit 1
   
   echo "$PKG: Prepare"
   make package/$PKG/prepare V=s || exit 1
   
   echo "$PKG: Compile"
   make package/$PKG/compile V=s || exit 1
fi
