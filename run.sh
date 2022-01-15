#!/usr/bin/env sh

### Dependencies
# bc musl kernel-headers-musl cpio

# Create directories
mkdir -p src
cd src

# Kernel
KERNEL_VERSION=5.16
KERNEL_MAJOR=$(echo $KERNEL_VERSION | cut -d"." -f1)
wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$KERNEL_MAJOR.x/linux-$KERNEL_VERSION.tar.xz
tar -xf linux-$KERNEL_VERSION.tar.xz
cd linux-$KERNEL_VERSION
make defconfig
make -j$(nproc) || exit 0
cd ..

# Busybox
BUSYBOX_VERSION=1.35.0
wget https://busybox.net/downloads/busybox-$BUSYBOX_VERSION.tar.bz2
tar -xf busybox-$BUSYBOX_VERSION.tar.bz2
cd busybox-$BUSYBOX_VERSION
make defconfig
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
make -j$(nproc) || exit 0
# if make fails  then install musl kernel-headers-musl
# make CC=musl-gcc -j$(nproc) busybox || exit 0
cd ..

cd ..

# Copy kernel
cp src/linux-5.16/arch/x86_64/boot/bzImage .

# Root dir
mkdir initrd
cd initrd
mkdir -p bin dev proc sys

# Soft link all busybox programs
cd bin
cp -r ../../src/busybox-$BUSYBOX_VERSION/busybox .
binaries=$(./busybox --list)
for binary in $binaries; do
	ln -s ./busybox ./$binary
done
cd ..

# Create init
echo "#!/bin/sh" >>init
echo "mount -t sysfs sysfs /sys" >>init
echo "mount -t proc proc /proc" >>init
echo "mount -t devtmpfs udev /dev" >>init
echo 'sysctl -w kernel.printk="2 4 1 7"' >>init
echo "/bin/sh" >>init
echo "poweroff -f" >>init
chmod -R 777 .
find . | cpio -o -H newc >../initrd.img

cd ..

# Run
# qemu-system-x86_64 -kernel bzImage -initrd initrd.img
qemu-system-x86_64 -kernel bzImage -initrd initrd.img -nographic -append 'console=ttyS0'
