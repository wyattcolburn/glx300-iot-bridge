set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR mips)

set(OPENWRT_TOOLCHAIN
    /home/wyatt/openwrt-sdk-22.03.4-ath79-generic_gcc-11.2.0_musl.Linux-x86_64/staging_dir/toolchain-mips_24kc_gcc-11.2.0_musl)

set(OPENWRT_TARGET
    /home/wyatt/openwrt-sdk-22.03.4-ath79-generic_gcc-11.2.0_musl.Linux-x86_64/staging_dir/target-mips_24kc_musl)

set(CMAKE_C_COMPILER   ${OPENWRT_TOOLCHAIN}/bin/mips-openwrt-linux-musl-gcc)
set(CMAKE_CXX_COMPILER ${OPENWRT_TOOLCHAIN}/bin/mips-openwrt-linux-musl-g++)
set(CMAKE_STRIP        ${OPENWRT_TOOLCHAIN}/bin/mips-openwrt-linux-musl-strip)

# Sysroot with cross-built mbedTLS
set(MIPS_SYSROOT "$ENV{HOME}/mips-sysroot")

# Toolchain defaults: soft-float, big-endian, mips32r2 — pin march and add sysroot includes
set(CMAKE_C_FLAGS_INIT   "-march=24kc -I${MIPS_SYSROOT}/include")
set(CMAKE_CXX_FLAGS_INIT "-march=24kc -I${MIPS_SYSROOT}/include")

# Static binary + sysroot lib path so linker finds libmbedtls.a etc.
set(CMAKE_EXE_LINKER_FLAGS_INIT "-static -L${MIPS_SYSROOT}/lib")

# Direct CMake find_* to look in our sysroot and the OpenWrt target dir
set(CMAKE_FIND_ROOT_PATH ${MIPS_SYSROOT} ${OPENWRT_TARGET})
set(CMAKE_PREFIX_PATH ${MIPS_SYSROOT})

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
