#!/bin/bash

WORKDIR="/workdir"
PATCHES_DIR="${WORKDIR}/patches"
OVERLAY_DIR="${WORKDIR}/overlay"

source "${WORKDIR}/build.conf.sh"

tempdir=$(mktemp -d -t build-XXXXXX)
rootfs="${tempdir}/rootfs"
kernel_src="${tempdir}/linux-${KERNEL_VERSION_NAME}"
esphosted_src="${tempdir}/esphosted"
alpine_apk="${tempdir}/apk"
root_uuid="$(uuidgen)"

kernel_fetch() {
  mkdir -p "${kernel_src}"
  wget "https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION}.x/linux-${KERNEL_VERSION_NAME}.tar.xz" -O "${tempdir}/linux-${KERNEL_VERSION_NAME}.tar.xz"
  pv "${tempdir}/linux-${KERNEL_VERSION_NAME}.tar.xz" | tar --strip-components=1 -xJC "${kernel_src}"
}

kernel_patch() {
  (
    cd "${kernel_src}"
    for patchfile in "$PATCHES_DIR"/*.patch; do patch -p1 <"$patchfile"; done
  )
}

kernel_build() {
  cp "${WORKDIR}/defconfig" "${kernel_src}/arch/${ARCH}/configs/build_defconfig"
  make -C "${kernel_src}" build_defconfig
  if [ -n "${CONFIG_KERNEL}" ]; then
    make -C "${kernel_src}" menuconfig
    make -C "${kernel_src}" savedefconfig
    cp "${kernel_src}/defconfig" "${WORKDIR}/defconfig-new"
  fi
  make -C "${kernel_src}" -j"$(nproc)"
}

kernel_install() {
  mkdir -p "${rootfs}" "${WORKDIR}/images/"
  make -C "${kernel_src}" -j"$(nproc)" targz-pkg
  pv "${kernel_src}/linux-${KERNEL_VERSION_NAME}-${ARCH}.tar.gz" | tar -C "${rootfs}" -xz
  cp "${kernel_src}/linux-${KERNEL_VERSION_NAME}-${ARCH}.tar.gz" "${WORKDIR}/images/"
}

esphosted_fetch() {
  git clone https://github.com/espressif/esp-hosted.git "${esphosted_src}"
  (cd "${esphosted_src}"; git checkout 24c86389142110706fb71f7df63979f0112c7580)
}

esphosted_kmod_build() {
  make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" KERNEL="${kernel_src}" -C "${esphosted_src}/esp_hosted_ng/host" all
}

esphosted_kmod_install() {
  mkdir -p "${rootfs}"
  make ARCH="${ARCH}" CROSS_COMPILE="${CROSS_COMPILE}" INSTALL_MOD_PATH="${rootfs}" M="${esphosted_src}/esp_hosted_ng/host" -C "${kernel_src}" modules_install
}

esphosted_fw_build() {
  (
    cd "${esphosted_src}/esp_hosted_ng/esp/esp_driver"
    ./setup.sh
    cd "${esphosted_src}/esp_hosted_ng/esp/esp_driver/esp-idf"
    . ./export.sh
    cd "${esphosted_src}/esp_hosted_ng/esp/esp_driver/network_adapter"
    idf.py set-target esp32
    idf.py build
  )
}

esphosted_fw_install() {
  mkdir -p "${rootfs}/lib/firmware/espressif/"
  cp -v "${esphosted_src}/esp_hosted_ng/esp/esp_driver/network_adapter/build/"{bootloader/bootloader.bin,partition_table/partition-table.bin,ota_data_initial.bin,network_adapter.bin} "${rootfs}/lib/firmware/espressif/"
}

alpine_fetch() {
  wget "https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/v2.14.6/$(arch)/apk.static" -O "$alpine_apk"
  chmod +x "$alpine_apk"
}

alpine_install() {
  "$alpine_apk" --arch "${ALPINE_ARCH}" -X "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main/" -X "http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community/" -U --allow-untrusted --root "${rootfs}" --initdb add alpine-base libgpiod iproute2-minimal alsa-utils can-utils
}

alpine_overlay_install() {
  cp -r "${OVERLAY_DIR}/." "${rootfs}/"
}

alpine_setup() {
  sed -i -e "s/%PARTUUID%/$root_uuid/g" -e "s/%KERNEL_VERSION%/$KERNEL_VERSION_NAME/g" "${rootfs}/boot/extlinux/extlinux.conf"
  sed -i -e "s/%PARTUUID%/$root_uuid/g" "${rootfs}/etc/fstab"
  sed -i -e "s/%ALPINE_VERSION%/v$ALPINE_VERSION/g" "${rootfs}/etc/apk/repositories"

  dd if=/dev/zero of="${rootfs}/swapfile" bs=1M count=64
  chmod 0600 "${rootfs}/swapfile"
  chown 0:0 "${rootfs}/swapfile"
  mkswap "${rootfs}/swapfile"

  ln -s /etc/init.d/boot "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/crond "${rootfs}/etc/runlevels/default/"
  ln -s /etc/init.d/devfs "${rootfs}/etc/runlevels/sysinit/"
  ln -s /etc/init.d/dmesg "${rootfs}/etc/runlevels/sysinit/"
  ln -s /etc/init.d/hostname "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/hwclock "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/hwdrivers "${rootfs}/etc/runlevels/sysinit/"
  ln -s /etc/init.d/killprocs "${rootfs}/etc/runlevels/shutdown/"
  ln -s /etc/init.d/mdev "${rootfs}/etc/runlevels/sysinit/"
  ln -s /etc/init.d/modules "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/mount-ro "${rootfs}/etc/runlevels/shutdown/"
  ln -s /etc/init.d/networking "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/savecache "${rootfs}/etc/runlevels/shutdown/"
  ln -s /etc/init.d/seedrng "${rootfs}/etc/runlevels/boot/"
  ln -s /etc/init.d/swap "${rootfs}/etc/runlevels/boot/"
}

genimage_package() {
  mkdir -p "${WORKDIR}/images"
  sed -e "s/%PARTUUID%/$root_uuid/g" -e "s/%ALPINE_VERSION%/$ALPINE_VERSION/g" -e "s/%ALPINE_ARCH%/$ALPINE_ARCH/g" -e "s:%ROOTFS_PATH%:$rootfs:g" "${WORKDIR}/genimage.cfg" >"${tempdir}/genimage.cfg"
  genimage --outputpath "${WORKDIR}/images" --config "${tempdir}/genimage.cfg"
  gzip -f "${WORKDIR}/images/alpine-kumquat-${ALPINE_VERSION}-${ALPINE_ARCH}.img"
}

set -e

kernel_fetch
kernel_patch
kernel_build
kernel_install

esphosted_fetch
esphosted_kmod_build
esphosted_kmod_install

esphosted_fw_build
esphosted_fw_install

alpine_fetch
alpine_install
alpine_overlay_install
alpine_setup

genimage_package
