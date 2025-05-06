# syntax=docker/dockerfile:1

ARG BASE_DOCKER=nvcr.io/nvidia/l4t-jetpack:r36.4.0
ARG BUILDPLATFORM=linux/arm64
ARG CXX=g++-11
ARG CC=gcc-11
ARG PYTHON=python3.10

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
    $CXX $CC \
    # Install pyton 3.10
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get install -y $PYTHON-venv $PYTHON-tk $PYTHON-dev \
    && curl -fsSL https://bootstrap.pypa.io/get-pip.py | $PYTHON - \
    && apt-get -qq clean \
    && $PYTHON -m pip install gdown

RUN curl -fsSL -o cmake.sh https://github.com/Kitware/CMake/releases/download/v3.31.3/cmake-3.31.3-linux-aarch64.sh \
    && bash cmake.sh --skip-license --prefix=/usr/local \
    && rm cmake.sh

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
    libpng-dev \
    libjpeg-dev \
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

# Final builder image
FROM base-builder

ENV HOME=/root
ENV TZ="Asia/Jerusalem"

RUN apt-get -qq update && apt-get -qq install --no-install-recommends \
    libgstreamer1.0-0 \
    libportaudio2 \
    gstreamer1.0-plugins-base \
    gstreamer1.0-plugins-good \
    gstreamer1.0-plugins-bad \
    gstreamer1.0-plugins-ugly \
    gstreamer1.0-libav \
    libgstreamer1.0-dev \
    libgstreamer-plugins-base1.0-dev \
    libgstrtspserver-1.0-dev \
    libgtk2.0-dev \
    liblz4-dev \
    libspdlog-dev \
    libzmq3-dev \
    libasound2-dev \
    libavcodec-dev \
    libavformat-dev \
    libavutil-dev \
    libswscale-dev \
    libtiff-dev \
    libjpeg-dev \
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
    libopenblas-dev \
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
    cmake \
    git \
    build-essential \
    && apt-get -qq clean

# Nvidia Jetson specific packages
# CUDA 12.6
RUN curl -LJ https://repo.download.nvidia.com/jetson/common/pool/main/c/cuda-runtime-12-6/cuda-runtime-12-6_12.6.11-1_arm64.deb -o /tmp/cuda-runtime-12-6_12.6.11-1_arm64.deb \
    && apt-get install -qq /tmp/cuda-runtime-12-6_12.6.11-1_arm64.deb \
    && rm -f /tmp/cuda-runtime-12-6_12.6.11-1_arm64.deb \
    && curl -LJ https://repo.download.nvidia.com/jetson/common/pool/main/c/cuda-12-6/cuda-12-6_12.6.11-1_arm64.deb -o /tmp/cuda-12-6_12.6.11-1_arm64.deb \
    && apt-get install -qq /tmp/cuda-12-6_12.6.11-1_arm64.deb \
    && rm -f /tmp/cuda-12-6_12.6.11-1_arm64.deb \
    && curl -LJ https://repo.download.nvidia.com/jetson/common/pool/main/c/cuda-toolkit-12/cuda-toolkit-12_12.6.11-1_arm64.deb -o /tmp/cuda-toolkit-12_12.6.11-1_arm64.deb \
    && apt-get install -qq /tmp/cuda-toolkit-12_12.6.11-1_arm64.deb \
    && rm -f /tmp/cuda-toolkit-12_12.6.11-1_arm64.deb

# OpenCV 4.8.0
RUN curl -LJ https://repo.download.nvidia.com/jetson/common/pool/main/libo/libopencv-dev/libopencv-dev_4.8.0-1-g6371ee1_arm64.deb -o /tmp/libopencv-dev_4.8.0-1-g6371ee1_arm64.deb \
    && apt-get install -qq /tmp/libopencv-dev_4.8.0-1-g6371ee1_arm64.deb \
    && rm -f /tmp/libopencv-dev_4.8.0-1-g6371ee1_arm64.deb \
    && curl -LJ https://repo.download.nvidia.com/jetson/common/pool/main/libo/libopencv-python/libopencv-python_4.8.0-1-g6371ee1_arm64.deb -o /tmp/libopencv-python_4.8.0-1-g6371ee1_arm64.deb \
    && apt-get install -qq /tmp/libopencv-python_4.8.0-1-g6371ee1_arm64.deb \
    && rm -f /tmp/libopencv-python_4.8.0-1-g6371ee1_arm64.deb

RUN gdown -O /tmp/pylon_7.2.1.deb "10nSrIWPe8KN879-SMDeR8enOyoOphviy" \
    && mkdir -p /opt/pylon \
    && apt install -y /tmp/pylon_7.2.1.deb \
    && chmod 755 /opt/pylon \
    && rm -f /tmp/pylon_7.2.1.deb

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf aws awscliv2.zip

COPY --from=boost-builder /dist /usr/local
COPY --from=nlohmann-builder /dist /usr/local
COPY --from=libvrs-builder /dist /usr/local
COPY --from=libjxl-builder /dist /usr/local

COPY pip.config /etc/pip.conf

ARG CC CXX PYTHON
ENV CC=$CC CXX=$CXX PYTHON=$PYTHON PYLON_ROOT=/opt/pylon

# create jenkins user
RUN groupadd -g 5000 services \
    && useradd -u 5000 -m -d /var/lib/jenkins -G sudo,services jenkins \
    && chsh -s /bin/bash jenkins
