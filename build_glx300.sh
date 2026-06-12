#!/usr/bin/env bash
set -euo pipefail

SDK=/home/wyatt/azure-iot-sdk-c
BUILD_DIR=/home/wyatt/glx300/build-mips
TOOLCHAIN=/home/wyatt/glx300/toolchain-mips-openwrt.cmake
SYSROOT=$HOME/mips-sysroot
MBEDTLS_VER=2.28.8

OPENWRT_TC=/home/wyatt/openwrt-sdk-22.03.4-ath79-generic_gcc-11.2.0_musl.Linux-x86_64/staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl
export PATH="$OPENWRT_TC/bin:$PATH"

# ── Step 1: Build mbedTLS for MIPS ────────────────────────────────────────
if [ ! -f "$SYSROOT/lib/libmbedtls.a" ]; then
    echo "=== Building mbedTLS $MBEDTLS_VER for MIPS ==="
    TMPDIR=$(mktemp -d)
    trap "rm -rf $TMPDIR" EXIT

    cd "$TMPDIR"
    curl -sL "https://github.com/Mbed-TLS/mbedtls/releases/download/v${MBEDTLS_VER}/mbedtls-${MBEDTLS_VER}.tar.bz2" | tar xj
    mkdir build-mbedtls && cd build-mbedtls

    cmake "../mbedtls-${MBEDTLS_VER}" \
        -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$SYSROOT" \
        -DENABLE_TESTING=OFF \
        -DENABLE_PROGRAMS=OFF \
        -DMBEDTLS_FATAL_WARNINGS=OFF

    make -j"$(nproc)"
    make install
    echo "=== mbedTLS installed to $SYSROOT ==="
else
    echo "=== mbedTLS already in $SYSROOT, skipping ==="
fi

# ── Step 2: CMake configure Azure IoT C SDK with mbedTLS ─────────────────
echo "=== Configuring Azure IoT C SDK for MIPS (mbedTLS) ==="
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

[ -f CMakeCache.txt ] && rm CMakeCache.txt

cmake "$SDK" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DCMAKE_BUILD_TYPE=Release \
    -Duse_openssl=OFF \
    -Duse_mbedtls=ON \
    -DCMAKE_PREFIX_PATH="$SYSROOT" \
    -Dskip_samples=OFF \
    -Duse_amqp=OFF \
    -Duse_http=OFF \
    -Duse_mqtt=ON \
    -Dbuild_service_client=OFF \
    -Dbuild_provisioning_service_client=OFF \
    -Duse_prov_client=OFF \
    -Drun_e2e_tests=OFF \
    -Drun_unittests=OFF \
    -Duse_default_uuid=ON

echo "=== Building glx300_telemetry ==="
make -j"$(nproc)" glx300_telemetry

BINARY="$BUILD_DIR/Release/glx300_telemetry"

echo "=== Binary info ==="
file "$BINARY"
ls -lh "$BINARY"

echo ""
echo "Deploy with:"
echo "  scp $BINARY root@192.168.8.1:/tmp/glx300_telemetry"
echo "  ssh root@192.168.8.1 '/tmp/glx300_telemetry; echo exit: \$?'"
