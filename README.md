# Kumquat Kernel Build

This repository contains scripts and Docker configurations to build a custom Linux kernel and ESP hosted firmware for Alpine Linux on ARM architecture. The build process includes fetching, patching, and compiling the kernel, as well as setting up the root filesystem with necessary packages and configurations.

## Prerequisites

- Docker

## Usage

To build the kernel and firmware, run the following command:

```bash
./run-docker.sh
```

This script will:
1. Build a Docker image named `kumquat-kernel-build`.
2. Run the Docker container, mounting the `./source` directory to `/workdir` inside the container.
3. Execute the `build.sh` script inside the container to perform the build process.

## Build Process

The `build.sh` script performs the following steps:
1. Fetches the Linux kernel source.
2. Applies patches to the kernel.
3. Builds the kernel.
4. Installs the kernel to the root filesystem.
5. Fetches and builds the ESP hosted kernel modules and firmware.
6. Installs the ESP hosted kernel modules and firmware to the root filesystem.
7. Fetches and installs Alpine Linux base and additional packages.
8. Applies overlay files to the root filesystem.
9. Sets up the root filesystem with necessary configurations.
10. Packages the root filesystem into a bootable image.

## License

This project is licensed under the GPLv2 License.