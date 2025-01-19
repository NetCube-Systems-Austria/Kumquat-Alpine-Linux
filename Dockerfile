FROM debian:bookworm

# Install the required packages
RUN apt-get update && apt-get install -y \
    gcc-arm-linux-gnueabihf binutils-arm-linux-gnueabihf \
    build-essential make wget patch xz-utils bzip2 \
    flex bison libssl-dev bc kmod debhelper cpio libelf-dev \
    rsync git e2fsprogs uuid-runtime genimage \ 
    gperf python3 python3-pip python3-venv cmake ninja-build \
    ccache libffi-dev dfu-util libusb-1.0-0 pv genext2fs \
    libncurses-dev

# Set environment variables
ENV CROSS_COMPILE=arm-linux-gnueabihf-
ENV ARCH=arm

WORKDIR /workdir
