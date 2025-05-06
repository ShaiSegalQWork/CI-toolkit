#!/bin/bash

set -e

#
# Install build dependencies in MSYS2 environment.
#
mingw_prefix=mingw-w64-ucrt-x86_64

prefix_deps=( cmake clang opencv nlohmann_json \
       cppzmq zeromq gstreamer gst-rtsp-server \
       spdlog protobuf libusb winpthreads-git )

non_prefix_deps=( git autotools getopt )

pacman --noconfirm --needed -S $(printf "${mingw_prefix}-%s\n" "${prefix_deps[@]}") "${non_prefix_deps[@]}"

# install libwdi
if ! pkg-config --exists libwdi; then
    tempdir=$(mktemp -d)
    trap "rm -rf \"$tempdir\"" EXIT
    wget -O- https://github.com/pbatard/libwdi/archive/refs/tags/v1.5.1.tar.gz | tar -C "$tempdir" -xzf-
    # note: autogen.sh exits with status 1 for no reason
    ( cd "$tempdir"/*; \
      ./autogen.sh --disable-debug --disable-32bit --with-libusb0="" --with-libusbk="" --disable-examples-build --disable-shared || true; \
      make -j3; \
      make install )
fi
