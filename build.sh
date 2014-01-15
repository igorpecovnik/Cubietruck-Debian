#!/bin/bash

# --- Configuration -------------------------------------------------------------
VERSION="CTDebian 1.4"
DEST_LANG="en_US"
DEST_LANGUAGE="en"
DEST=/tmp/Cubie
DISPLAY=3  # "0:none; 1:lcd; 2:tv; 3:hdmi; 4:vga"
# --- End -----------------------------------------------------------------------
SRC=$(pwd)
set -e

#Requires root ..
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo "Building Cubietruck-Debian in $DEST from $SRC"
sleep 3
#--------------------------------------------------------------------------------
# Downloading necessary files
#--------------------------------------------------------------------------------
echo "------ Downloading necessary files"
apt-get -qq -y install binfmt-support bison build-essential ccache debootstrap flex gawk gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf gettext linux-headers-generic linux-image-generic lvm2 qemu-user-static texinfo texlive u-boot-tools uuid-dev zlib1g-dev unzip libncurses5-dev pkg-config libusb-1.0-0-dev

#--------------------------------------------------------------------------------
# Preparing output / destination files
#--------------------------------------------------------------------------------

echo "------ Fetching files from github"
mkdir -p $DEST/output
cp output/uEnv.txt $DEST/output

if [ -d "$DEST/u-boot-sunxi" ]
then
	cd $DEST/u-boot-sunxi ; git pull; cd $SRC
else
	git clone https://github.com/cubieboard/u-boot-sunxi $DEST/u-boot-sunxi # Boot loader
fi
if [ -d "$DEST/sunxi-tools" ]
then
	cd $DEST/sunxi-tools; git pull; cd $SRC
else
	git clone https://github.com/linux-sunxi/sunxi-tools.git $DEST/sunxi-tools # Allwinner tools
fi
if [ -d "$DEST/cubie_configs" ]
then
	cd $DEST/cubie_configs; git pull; cd $SRC
else
	git clone https://github.com/cubieboard/cubie_configs $DEST/cubie_configs # Hardware configurations
fi
if [ -d "$DEST/linux-sunxi" ]
then
	cd $DEST/linux-sunxi; git pull -f; cd $SRC
else
	# git clone https://github.com/cubieboard/linux-sunxi/ $DEST/linux-sunxi # Kernel 3.4.61+
	git clone https://github.com/patrickhwood/linux-sunxi -b pat-3.4.75-ct $DEST/linux-sunxi # Patwood's kernel 3.4.75+
fi

# Adding wlan firmware to kernel source
cd $DEST/linux-sunxi/firmware; wget -q https://www.dropbox.com/s/o3evaiuidtg6xb5/ap6210.zip -O temp.zip; unzip -o temp.zip; rm temp.zip

# Applying Patch for 2gb memory
#patch -f $DEST/u-boot-sunxi/include/configs/sunxi-common.h < $SRC/patch/memory.patch || true

# Applying Patch for gpio
#patch -f $DEST/linux-sunxi/drivers/gpio/gpio-sunxi.c < $SRC/patch/gpio.patch || true

# Applying Patch for high load. Could cause troubles with USB OTG port
sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct.fex

# Prepare fex files for VGA & HDMI
sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/ct.fex > $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/ct.fex > $DEST/cubie_configs/sysconfig/linux/ct-vga.fex


# Copying Kernel config
cp $SRC/config/kernel.config $DEST/linux-sunxi/

#--------------------------------------------------------------------------------
# Compiling everything
#--------------------------------------------------------------------------------
#if false; then
echo "------ Compiling kernel boot loaderb"
cd $DEST/u-boot-sunxi
# boot loader
make clean && make -j2 'cubietruck' CROSS_COMPILE=arm-linux-gnueabihf-
echo "------ Compiling sunxi tools"
cd $DEST/sunxi-tools
# sunxi-tools
make clean && make fex2bin && make bin2fex
cp fex2bin bin2fex /usr/local/bin/
# hardware configuration
fex2bin $DEST/cubie_configs/sysconfig/linux/ct-vga.fex $DEST/output/script-vga.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex $DEST/output/script-hdmi.bin

# kernel image
echo "------ Compiling kernel"
cd $DEST/linux-sunxi
make clean
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- sun7i_defconfig
# get proven config
cp $DEST/linux-sunxi/kernel.config $DEST/linux-sunxi/.config
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage modules
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output headers_install
#fi

#--------------------------------------------------------------------------------
# Creating SD Images
#--------------------------------------------------------------------------------
echo "------ Creating SD Images"
cd $DEST/output
# create 1Gb image and mount image to /dev/loop0
dd if=/dev/zero of=debian_rootfs.raw bs=1M count=1000
umount -l /dev/loop0 || true
umount -l /dev/loop1 || true
losetup -d /dev/loop0 || true
losetup -d /dev/loop1 || true
losetup /dev/loop0 debian_rootfs.raw 

echo "------ Partitionning and mounting filesystem"
# make image bootable
dd if=$DEST/u-boot-sunxi/u-boot-sunxi-with-spl.bin of=/dev/loop0 bs=1024 seek=8

# create one partition starting at 2048 which is default
(echo n; echo p; echo 1; echo; echo; echo w) | fdisk /dev/loop0 >> /dev/null || true
# just to make sure
partprobe /dev/loop0

# 2048 (start) x 512 (block size) = where to mount partition
losetup -o 1048576 /dev/loop1  /dev/loop0
# create filesystem
mkfs.ext4 /dev/loop1
# create mount point and mount image 
mkdir -p $DEST/output/sdcard/
mount /dev/loop1 $DEST/output/sdcard/

echo "------ Install basic filesystem"
# install base system
debootstrap --no-check-gpg --arch=armhf --foreign wheezy $DEST/output/sdcard/
# we need this
cp /usr/bin/qemu-arm-static $DEST/output/sdcard/usr/bin/
# mount proc inside chroot
mount -t proc chproc $DEST/output/sdcard/proc
# second stage unmounts proc 
chroot $DEST/output/sdcard /bin/bash -c "/debootstrap/debootstrap --second-stage"
# mount proc, sys and dev
mount -t proc chproc $DEST/output/sdcard/proc
mount -t sysfs chsys $DEST/output/sdcard/sys
# This works on half the systems I tried.  Else use bind option
mount -t devtmpfs chdev $DEST/output/sdcard/dev || mount --bind /dev $DEST/output/sdcard/dev
mount -t devpts chpts $DEST/output/sdcard/dev/pts

# update /etc/issue
cat <<EOT > $DEST/output/sdcard/etc/issue
Debian GNU/Linux 7 $VERSION

EOT

# update /etc/motd
cat > $DEST/output/sdcard/etc/motd <<EOF
              _      _        _                       _    
  ___  _   _ | |__  (_)  ___ | |_  _ __  _   _   ___ | | __
 / __|| | | || '_ \ | | / _ \| __|| '__|| | | | / __|| |/ /
| (__ | |_| || |_) || ||  __/| |_ | |   | |_| || (__ |   < 
 \___| \__,_||_.__/ |_| \___| \__||_|    \__,_| \___||_|\_\
                                                          

EOF


# apt list
cat <<EOT > $DEST/output/sdcard/etc/apt/sources.list
deb http://http.debian.net/debian wheezy main contrib non-free
deb-src http://http.debian.net/debian wheezy main contrib non-free
deb http://http.debian.net/debian wheezy-updates main contrib non-free
deb-src http://http.debian.net/debian wheezy-updates main contrib non-free
deb http://security.debian.org/debian-security wheezy/updates main contrib non-free
deb-src http://security.debian.org/debian-security wheezy/updates main contrib non-free
EOT

# update
chroot $DEST/output/sdcard /bin/bash -c "apt-get update"
chroot $DEST/output/sdcard /bin/bash -c "export LANG=C"    

# set up 'apt
cat <<END > $DEST/output/sdcard/etc/apt/apt.conf.d/71-no-recommends
APT::Install-Recommends "0";
APT::Install-Suggests "0";
END

# script to turn off the LED blinking
cp $SRC/scripts/disable_led.sh $DEST/output/sdcard/etc/init.d/disable_led.sh

# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/disable_led.sh"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d disable_led.sh defaults" 

# scripts for autoresize at first boot from cubian
cd $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-resize2fs $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-firstrun $DEST/output/sdcard/etc/init.d

# script to install to NAND
cp $SRC/scripts/nand-install.sh $DEST/output/sdcard/root


# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/cubian-*"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d cubian-firstrun defaults" 
# install and configure locales
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install locales"
# reconfigure locales
echo -e $DEST_LANG'.UTF-8 UTF-8\n' > $DEST/output/sdcard/etc/locale.gen 
chroot $DEST/output/sdcard /bin/bash -c "locale-gen"
echo -e 'LANG="'$DEST_LANG'.UTF-8"\nLANGUAGE="'$DEST_LANG':'$DEST_LANGUAGE'"\n' > $DEST/output/sdcard/etc/default/locale
chroot $DEST/output/sdcard /bin/bash -c "export LANG=$DEST_LANG.UTF-8"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install git dosfstools htop openssh-server ca-certificates module-init-tools dhcp3-client udev ifupdown iproute dropbear iputils-ping ntpdate ntp rsync usbutils uboot-envtools pciutils wireless-tools wpasupplicant procps libnl-dev parted cpufrequtils console-setup unzip bridge-utils" 
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y upgrade"

# configure MIN / MAX Speed for cpufrequtils
sed -e 's/MIN_SPEED="0"/MIN_SPEED="480000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/MAX_SPEED="0"/MAX_SPEED="1010000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/ondemand/interactive/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils

# set password to 1234
chroot $DEST/output/sdcard /bin/bash -c "(echo 1234;echo 1234;) | passwd root" 

# set hostname 
echo cubie > $DEST/output/sdcard/etc/hostname

# load modules
cat <<EOT >> $DEST/output/sdcard/etc/modules
hci_uart
gpio_sunxi
bcmdhd
#sunxi_gmac
EOT

# create interfaces configuration
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
        hwaddress ether AE:50:30:27:5A:CF # change this
#        pre-up /sbin/ifconfig eth0 mtu 3838 # setting MTU for DHCP, static just: mtu 3838
#auto wlan0
#allow-hotplug wlan0
#iface wlan0 inet dhcp
#    wpa-ssid SSID 
#    wpa-psk xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# to generate proper encrypted key: wpa_passphrase yourSSID yourpassword
EOT

# enable serial console (Debian/sysvinit way)
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $DEST/output/sdcard/etc/inittab

cp $DEST/output/uEnv.txt $DEST/output/sdcard/boot/
cp $DEST/linux-sunxi/arch/arm/boot/uImage $DEST/output/sdcard/boot/

# copy proper bin file
if [ $DISPLAY == 4 ]; then
cp $DEST/output/script-vga.bin $DEST/output/sdcard/boot/script.bin
else
cp $DEST/output/script-hdmi.bin $DEST/output/sdcard/boot/script.bin
fi

cp -R $DEST/linux-sunxi/output/lib/modules $DEST/output/sdcard/lib/
cp -R $DEST/linux-sunxi/output/lib/firmware/ $DEST/output/sdcard/lib/

#cd $DEST/output/sdcard/lib/firmware
#wget https://www.dropbox.com/s/o3evaiuidtg6xb5/ap6210.zip
#unzip ap6210.zip
#rm ap6210.zip
#cd $DEST/

# USB redirector tools http://www.incentivespro.com
cd $DEST
wget http://www.incentivespro.com/usb-redirector-linux-arm-eabi.tar.gz
tar xvfz usb-redirector-linux-arm-eabi.tar.gz
rm usb-redirector-linux-arm-eabi.tar.gz
cd $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd
make -j2 ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNELDIR=$DEST/linux-sunxi/
# configure USB redirector
sed -e 's/%INSTALLDIR_TAG%/\/usr\/local/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%PIDFILE_TAG%/\/var\/run\/usbsrvd.pid/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
sed -e 's/%STUBNAME_TAG%/tusbd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1
sed -e 's/%DAEMONNAME_TAG%/usbsrvd/g' $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd1 > $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
chmod +x $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd
# copy to root
cp $DEST/usb-redirector-linux-arm-eabi/files/usb* $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd/tusbd.ko $DEST/output/sdcard/usr/local/bin/ 
cp $DEST/usb-redirector-linux-arm-eabi/files/rc.usbsrvd $DEST/output/sdcard/etc/init.d/
# started by default ----- update.rc rc.usbsrvd defaults
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d rc.usbsrvd defaults"

# sunxi-tools
cd $DEST/sunxi-tools
make clean && make -j2 'fex2bin' CC=arm-linux-gnueabihf-gcc && make -j2 'bin2fex' CC=arm-linux-gnueabihf-gcc && make -j2 'nand-part' CC=arm-linux-gnueabihf-gcc
cp fex2bin $DEST/output/sdcard/usr/bin/ 
cp bin2fex $DEST/output/sdcard/usr/bin/
cp nand-part $DEST/output/sdcard/usr/bin/

# cleanup 
# unmount proc, sys and dev from chroot
umount $DEST/output/sdcard/dev/pts
umount $DEST/output/sdcard/dev
umount $DEST/output/sdcard/proc
umount $DEST/output/sdcard/sys

rm $DEST/output/sdcard/usr/bin/qemu-arm-static 
# umount images 
umount $DEST/output/sdcard/ 
losetup -d /dev/loop1 
losetup -d /dev/loop0
# compress image 
gzip $DEST/output/*.raw
