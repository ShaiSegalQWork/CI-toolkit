# syntax=docker/dockerfile:1

ARG BASE_DOCKER=ubuntu:focal
ARG CXX=g++-10
ARG CC=gcc-10
ARG PYTHON=python3.10

ARG GSTREAMER_TAG=1.24.12

FROM ${BASE_DOCKER} AS base-builder

ARG CC CXX PYTHON
ARG DEBIAN_FRONTEND=noninteractive
ARG CMAKE_PREFIX_PATH=/dist

RUN apt-get -qq update && apt-get -qq install \
    software-properties-common \
    build-essential \
    ninja-build \
    curl \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    $CXX $CC \
    # Install pyton 3.10
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get install -y $PYTHON-venv $PYTHON-tk $PYTHON-dev \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON - \
    && apt-get -qq clean \
    && $PYTHON -m pip install gdown

RUN curl -fsSL -o cmake.sh https://github.com/Kitware/CMake/releases/download/v3.31.3/cmake-3.31.3-linux-x86_64.sh \
    && bash cmake.sh --skip-license --prefix=/usr/local \
    && rm cmake.sh

FROM base-builder AS gstreamer-builder

ARG CC CXX

RUN apt-get -qq update && apt-get -qq install \
    flex \
    bison \
    libpulse-dev \
    python3.8-dev \
    nasm
RUN pip3 install meson
RUN git clone --depth 1 -b 1.80.1 https://gitlab.gnome.org/GNOME/gobject-introspection.git && cd gobject-introspection \
    && meson setup --prefix=/usr/local/ -D buildtype=release -D debug=false \
                   _build \
    && meson compile -C _build \
    && meson install -C _build && ldconfig \
    && cd .. && rm -rf ~-
RUN git clone --depth 1 -b 2.83.5 https://gitlab.gnome.org/GNOME/glib.git && cd glib \
    && meson setup --prefix=/usr/local/ -D buildtype=release -D debug=false -D glib_debug=disabled -D tests=false \
                                        -D introspection=enabled \
                   _build \
    && meson compile -C _build \
    && meson install -C _build && ldconfig \
    && cd .. && rm -rf ~-
RUN git clone --depth 1 -b 1.24.12 https://gitlab.freedesktop.org/gstreamer/gstreamer.git \
    && cd gstreamer \
    && meson setup --prefix=/usr/local -D buildtype=release -D debug=false -Db_lto=true -D b_staticpic=true \
                   -D examples=disabled -D gst-examples=disabled -D tests=disabled -D gpl=enabled \
                   -D introspection=enabled -D libav=disabled \
                   build \
    && meson compile -C build \
    && meson install -C build \
    && cd .. && rm -rf ~-
RUN mv /usr/local /dist

FROM base-builder AS opencv-builder

RUN apt-get -qq update && apt-get -qq install \
    pkg-config \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libavresample-dev \
    && apt-get -qq clean

COPY --from=gstreamer-builder /dist /usr/local

RUN curl -fsSL https://github.com/opencv/opencv/archive/refs/tags/4.6.0.tar.gz | tar -xzf - && \
    cd opencv-4.6.0 && \
    CFLAGS=-fPIC cmake -D BUILD_SHARED_LIBS=off -D BUILD_opencv_apps=off -D BUILD_DOCS=off -D BUILD_PERF_TESTS=off -D BUILD_TESTS=off -G Ninja -B build . && \
    cmake --build build && \
    cmake --install build --prefix /dist && \
    cd .. && rm -rf ~-


FROM base-builder AS boost-builder

ARG CC CXX

# Build boost with PIC static libs
RUN curl -fsSL https://archives.boost.io/release/1.87.0/source/boost_1_87_0.tar.gz | tar -xzf - && \
    cd boost_1_87_0 && \
    ./bootstrap.sh --prefix=/dist && \
    ./b2 --toolset=$CC cflags=-fPIC cxxflags=-fPIC link=static install && \
    cd .. && rm -rf ~-


FROM base-builder AS libvrs-builder

ARG CC CXX

RUN apt-get -qq update && apt-get -qq install \
    liblz4-dev \
    libzstd-dev \
    libxxhash-dev \
    libturbojpeg0-dev && apt-get -qq clean

COPY --from=boost-builder /dist /boost
ENV BOOST_ROOT=/boost

RUN curl -fsSL https://github.com/fmtlib/fmt/archive/refs/tags/10.2.1.tar.gz | tar -xzf - && \
    cd fmt-10.2.1 && \
    cmake -D FMT_TEST=off -G Ninja -B build . && \
    cmake --build build && \
    cmake --install build --prefix /dist && \
    cd .. && rm -rf ~-

RUN curl -fsSL https://github.com/facebookresearch/vrs/archive/refs/tags/v1.3.0.tar.gz | tar -xzf - && \
    cd vrs-1.3.0 && \
    cmake -G Ninja -D UNIT_TESTS=off -D BUILD_SAMPLES=off -D BUILD_TOOLS=off -B build . && \
    cmake --build build && \
    cmake --install build --prefix /dist && \
    cd .. && rm -rf ~-


FROM base-builder AS nlohmann-builder

ARG CC CXX

RUN curl -fsSL https://github.com/nlohmann/json/archive/refs/tags/v3.11.2.tar.gz | tar -xzf - && \
    cd json-3.11.2 && \
    cmake -G Ninja -D JSON_BuildTests=off -B build . && \
    cmake --build build && \
    cmake --install build --prefix /dist && \
    cd .. && rm -rf ~-


FROM base-builder AS libjxl-builder

ARG CC CXX

RUN curl -fsSL https://github.com/libjxl/libjxl/archive/refs/tags/v0.11.1.tar.gz | tar -xzf - && \
    cd libjxl-0.11.1 && \
    ./deps.sh && \
    cmake -D BUILD_TESTING=off -D JPEGXL_ENABLE_FUZZERS=off -D JPEGXL_ENABLE_TOOLS=off -D JPEGXL_ENABLE_JPEGLI=off \
          -D JPEGXL_ENABLE_DOXYGEN=off -D JPEGXL_ENABLE_MANPAGES=off -D JPEGXL_ENABLE_BENCHMARK=off -D JPEGXL_ENABLE_EXAMPLES=off \
          -D JPEGXL_BUNDLE_LIBPNG=off -D JPEGXL_ENABLE_JNI=off -D JPEGXL_ENABLE_SJPEG=off -D JPEGXL_ENABLE_OPENEXR=off \
          -D JPEGXL_ENABLE_TRANSCODE_JPEG=off -D JPEGXL_STATIC=on -D HWY_ENABLE_EXAMPLES=off -D HWY_ENABLE_INSTALL=on \
          -D HWY_ENABLE_TESTS=off \
          -G Ninja -B build . && \
    cmake --build build && \
    cmake --install build --prefix /dist && \
    cd .. && rm -rf ~-



FROM base-builder AS toolchain-installer

RUN mkdir /toolchains

# CX3 toolchain
RUN curl -fsSL https://developer.arm.com/-/media/Files/downloads/gnu/13.2.rel1/binrel/arm-gnu-toolchain-13.2.rel1-x86_64-arm-none-eabi.tar.xz | tar -xJf - \
    && mv arm-gnu-toolchain-13.2.Rel1-x86_64-arm-none-eabi /toolchains/armgcc

# STM32 toolchain
RUN gdown -O stm32cubeclt.zip "16zPE8M7QMBeFOqzyPMyDEubXOxlypSC-" \
    && unzip -p stm32cubeclt.zip > temp.sh \
    && bash temp.sh --tar -f -xO --wildcards './st-stm32cubeclt*.tar.gz' | tar -xzf - ./GNU-tools-for-STM32 \
    && mv GNU-tools-for-STM32 /toolchains/stm32 \
    && rm temp.sh stm32cubeclt.zip


# Final builder image
FROM base-builder

ENV HOME=/root
ENV TZ="Asia/Jerusalem"

RUN apt-get -qq update && apt-get -qq install --no-install-recommends \
    libportaudio2 \
    libboost-all-dev \
    libgstrtspserver-1.0-dev \
    libgtk2.0-dev \
    liblz4-dev \
    libspdlog-dev \
    libzmqpp-dev \
    libasound2-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libavresample-dev \
    libtiff-dev \
    libzstd-dev \
    libxxhash-dev \
    libturbojpeg0-dev \
    libpq-dev \
    libcairo2-dev \
    libgirepository1.0-dev \
    pybind11-dev \
    libusb-dev \
    libusb-1.0-0-dev \
    libdw-dev \
    libdw1 \
    libwebp-dev \
    libbz2-dev \
    libuvc-dev \
    protobuf-compiler \
    protobuf-c-compiler \
    libprotobuf-c-dev \
    tzdata \
    ffmpeg \
    fuse \
    lnav \
    nano \
    nmon \
    postgresql \
    rsync \
    snapd \
    squashfuse \
    sudo \
    v4l-utils \
    zip \
    && apt-get -qq clean

RUN gdown -O /tmp/pylon_7.2.1.deb "1tC7D6BlOZ2BilNpEtVCY6Wx9siHy4jtK" \
    && mkdir -p /opt/pylon \
    && apt-get install -qq /tmp/pylon_7.2.1.deb \
    && chmod 755 /opt/pylon \
    && rm -f /tmp/pylon_7.2.1.deb

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

COPY --from=boost-builder /dist /usr/local
COPY --from=nlohmann-builder /dist /usr/local
COPY --from=libvrs-builder /dist /usr/local
COPY --from=libjxl-builder /dist /usr/local
COPY --from=opencv-builder /dist /usr/local
COPY --from=gstreamer-builder /dist /usr/local
COPY --from=toolchain-installer /toolchains /toolchains

# get rid of gstreamer from APT to avoid colliison with our own build
RUN apt-get -qq autoremove libgstreamer1.0-0 python3-gi && ldconfig \
    && $PYTHON -m pip install pygobject

COPY pip.config /etc/pip.conf

ENV ARMGCC_INSTALL_PATH=/toolchains/cx3
ENV STM32_TOOLCHAIN_PATH=/toolchains/stm32/bin
ARG CC CXX PYTHON
ENV CC=$CC CXX=$CXX PYTHON=$PYTHON

# create jenkins user
RUN groupadd -g 5000 services \
    && useradd -u 5000 -m -d /var/lib/jenkins -G sudo,services jenkins \
    && chsh -s /bin/bash jenkins