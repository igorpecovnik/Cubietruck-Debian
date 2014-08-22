#!/bin/bash
#
# Created by Igor Pecovnik, www.igorpecovnik.com
#
# --- Configuration -------------------------------------------------------------
#
#

RELEASE="wheezy"                                   # jessie or wheezy
VERSION="CTDebian 2.6 $RELEASE"                    # just name
SOURCE_COMPILE="yes"                               # yes / no
DEST_LANG="en_US.UTF-8"                            # sl_SI.UTF-8, en_US.UTF-8
TZDATA="Europe/Ljubljana"                          # Timezone
DEST=$(pwd)/output                                 # Destination
ROOTPWD="1234"                                     # Must be changed @first login
HOST="cubie"									   # Hostname

#
#
# --- End -----------------------------------------------------------------------

# source is where we start the script
SRC=$(pwd)
set -e

# optimize build time with 100% CPU usage
CPUS=$(grep -c 'processor' /proc/cpuinfo)
CTHREADS="-j$(($CPUS + $CPUS/2))"
#CTHREADS="-j${CPUS}" # or not

# to display build time at the end
start=`date +%s`

# root is required ...
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

clear
echo "Building $VERSION."

#--------------------------------------------------------------------------------
# Downloading necessary files
#--------------------------------------------------------------------------------
echo "Downloading necessary files."
#apt-get -qq -y install zip binfmt-support bison build-essential ccache debootstrap flex gawk gcc-arm-linux-gnueabi gcc-arm-linux-gnueabihf lvm2 qemu-user-static texinfo texlive u-boot-tools uuid-dev zlib1g-dev unzip libncurses5-dev pkg-config libusb-1.0-0-dev parted

#--------------------------------------------------------------------------------
# Preparing output / destination files
#--------------------------------------------------------------------------------

echo "Fetching files from Github."
mkdir -p $DEST/output

if [ -d "$DEST/u-boot-sunxi-next" ]
then
	cd $DEST/u-boot-sunxi-next ; git pull; cd $SRC
else
	git clone https://github.com/jwrdegoede/u-boot-sunxi/ -b next $DEST/u-boot-sunxi-next            # For booting experimental kernel
fi

if [ -d "$DEST/u-boot-sunxi" ]
then
	cd $DEST/u-boot-sunxi ; git pull; cd $SRC
else
	git clone https://github.com/patrickhwood/u-boot -b pat-cb2-ct  $DEST/u-boot-sunxi               # Cubieboard 2 / Cubietruck Dual boot loader
fi
if [ -d "$DEST/sunxi-tools" ]
then
	cd $DEST/sunxi-tools; git pull; cd $SRC
else
	git clone https://github.com/linux-sunxi/sunxi-tools.git $DEST/sunxi-tools                       # Allwinner tools
fi
if [ -d "$DEST/cubie_configs" ]
then
	cd $DEST/cubie_configs; git pull; cd $SRC
else
	git clone https://github.com/cubieboard/cubie_configs $DEST/cubie_configs                       # Hardware configurations
fi
if [ -d "$DEST/linux-sunxi-next" ]
then
	cd $DEST/linux-sunxi-next; git pull -f; cd $SRC
else
	git clone https://github.com/linux-sunxi/linux-sunxi/ -b sunxi-next $DEST/linux-sunxi-next      # Experimental kernel source
fi
if [ -d "$DEST/linux-sunxi" ]
then
	cd $DEST/linux-sunxi; git pull -f; cd $SRC
else
	git clone https://github.com/dan-and/linux-sunxi $DEST/linux-sunxi -b dan-3.4.103               # Stable kernel source
fi
if [ -d "$DEST/sunxi-lirc" ]
then
	cd $DEST/sunxi-lirc; git pull -f; cd $SRC
else
	git clone https://github.com/matzrh/sunxi-lirc $DEST/sunxi-lirc                                 # Lirc RX and TX functionality for Allwinner A1X and A20 chips
fi


if [ "$SOURCE_COMPILE" = "yes" ]; then

#--------------------------------------------------------------------------------
# Patching
#--------------------------------------------------------------------------------

# Applying Patch for CB2 stability
sed -e 's/.clock = 480/.clock = 432/g' -i $DEST/u-boot-sunxi/board/sunxi/dram_cubieboard2.c 

# Applying patch for crypt and some performance tweaks
cd $DEST/linux-sunxi/ 
#patch -p1 < $SRC/patch/0001-system-more-responsive-in-case-multiple-tasks.patch
#patch -p1 < $SRC/patch/crypto.patch
#patch -p1 < $SRC/patch/disp_vsync.patch
#patch -p1 < $SRC/patch/chip_id.patch
patch -p1 < $SRC/patch/gpio.patch

# Applying Patch for "high load". Could cause troubles with USB OTG port
sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubietruck.fex 
sed -e 's/usb_detect_type     = 1/usb_detect_type     = 0/g' -i $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex

# Prepare fex files for VGA & HDMI
sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/cubietruck.fex > $DEST/cubie_configs/sysconfig/linux/ct-vga.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 3/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex
sed -e 's/screen0_output_type.*/screen0_output_type     = 4/g' $DEST/cubie_configs/sysconfig/linux/cubieboard2.fex > $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex

#--------------------------------------------------------------------------------
# Compiling everything
#--------------------------------------------------------------------------------

# boot loader
echo "------ Compiling universal boot loader"
cd $DEST/u-boot-sunxi
make clean && make $CTHREADS 'cubietruck' CROSS_COMPILE=arm-linux-gnueabihf-

# boot loader next
cd $DEST/u-boot-sunxi-next
make clean && make $CTHREADS Cubietruck_defconfig CROSS_COMPILE=arm-linux-gnueabihf- && make $CTHREADS CROSS_COMPILE=arm-linux-gnueabihf-
# currently broken. using binary
#cp $SRC/bin/uboot-next.bin $DEST/u-boot-sunxi-next/u-boot-sunxi-with-spl.bin

# sunxi tools
echo "------ Compiling sun-xi tools"
cd $DEST/sunxi-tools
make clean && make fex2bin && make bin2fex
cp fex2bin bin2fex /usr/local/bin/

# kernel image stable
echo "------ Compiling kernel"
cd $DEST/linux-sunxi
make clean
# Adding wlan firmware to kernel source
cd $DEST/linux-sunxi/firmware; 
unzip -o $SRC/bin/ap6210.zip
cd $DEST/linux-sunxi
# get proven config
cp $SRC/config/kernel.config $DEST/linux-sunxi/.config
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- uImage modules
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output/usr headers_install
cp $DEST/linux-sunxi/Module.symvers $DEST/linux-sunxi/output/usr/include
# kernel image experimental
cd $DEST/linux-sunxi-next
make clean
cp $SRC/config/kernel.config.next $DEST/linux-sunxi-next/.config
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- LOADADDR=0x40008000 uImage modules dtbs
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_MOD_PATH=output modules_install
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- INSTALL_HDR_PATH=output/usr headers_install
cp $DEST/linux-sunxi/Module.symvers $DEST/linux-sunxi-next/output/usr/include
fi

#--------------------------------------------------------------------------------
# Creating boot directory for current and next kernel
#--------------------------------------------------------------------------------
# 
mkdir -p $DEST/output/boot/
# Current 
fex2bin $DEST/cubie_configs/sysconfig/linux/ct-vga.fex $DEST/output/boot/ct-vga.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/ct-hdmi.fex $DEST/output/boot/ct-hdmi.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-hdmi.fex $DEST/output/boot/cb2-hdmi.bin
fex2bin $DEST/cubie_configs/sysconfig/linux/cb2-vga.fex $DEST/output/boot/cb2-vga.bin
cp $SRC/config/uEnv.* $DEST/output/boot/
cp $DEST/u-boot-sunxi/u-boot-sunxi-with-spl.bin $DEST/output/boot/uboot.bin
cp $SRC/output/linux-sunxi/arch/arm/boot/uImage $DEST/output/boot/uImage
# Next
cp $SRC/config/boot.cmd $DEST/output/boot/
mkimage -C none -A arm -T script -d $DEST/output/boot/boot.cmd $DEST/output/boot/boot.scr.disabled
cp $DEST/u-boot-sunxi-next/u-boot-sunxi-with-spl.bin $DEST/output/boot/uboot-next.bin
mkdir -p $DEST/output/boot/dts
cp $DEST/linux-sunxi-next/arch/arm/boot/dts/*20-cubie*.dtb $DEST/output/boot/dts/
cp $SRC/output/linux-sunxi-next/arch/arm/boot/uImage $DEST/output/boot/uImage-next


#--------------------------------------------------------------------------------
# Creating kernel packages: modules + headers + firmware
#--------------------------------------------------------------------------------
#
# Current 
VER=$(cat $DEST/linux-sunxi/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-sunxi/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-sunxi/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
cd $SRC/output/linux-sunxi/output
tar cPf $DEST"/output/sunxi_kernel_"$VER"_mod_head_fw.tar" *
cd $DEST/output/
tar rPf $DEST"/output/sunxi_kernel_"$VER"_mod_head_fw.tar" boot/*
# creating MD5 sum
md5sum sunxi_kernel_"$VER"_mod_head_fw.tar > sunxi_kernel_"$VER"_mod_head_fw.md5
zip sunxi_kernel_"$VER"_mod_head_fw.zip sunxi_kernel_"$VER"_mod_head_fw.*
# Next
VER=$(cat $DEST/linux-sunxi-next/Makefile | grep VERSION | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-sunxi-next/Makefile | grep PATCHLEVEL | head -1 | awk '{print $(NF)}')
VER=$VER.$(cat $DEST/linux-sunxi-next/Makefile | grep SUBLEVEL | head -1 | awk '{print $(NF)}')
cd $SRC/output/linux-sunxi-next/output
tar cPf $DEST"/output/sunxi_kernel_"$VER"_mod_head_fw.tar" *
cd $DEST/output/
tar rPf $DEST"/output/sunxi_kernel_"$VER"_mod_head_fw.tar" boot/*
# creating MD5 sum
md5sum sunxi_kernel_"$VER"_mod_head_fw.tar > sunxi_kernel_"$VER"_mod_head_fw.md5
zip sunxi_kernel_"$VER"_mod_head_fw.zip sunxi_kernel_"$VER"_mod_head_fw.*

#--------------------------------------------------------------------------------
# Creating SD Images
#--------------------------------------------------------------------------------
echo "------ Creating SD Images"
cd $DEST/output
# create 1G image and mount image to next free loop device
dd if=/dev/zero of=debian_rootfs.raw bs=1M count=1000 status=noxfer
LOOP=$(losetup -f)
losetup $LOOP debian_rootfs.raw
sync

echo "Partitioning, writing boot loader and mounting file-system."
# create one partition starting at 2048 which is default
parted -s $LOOP -- mklabel msdos
sleep 1
parted -s $LOOP -- mkpart primary ext4  2048s -1s
sleep 1
partprobe $LOOP
sleep 1

echo "Writing boot loader."
dd if=$DEST/output/boot/uboot.bin of=$LOOP bs=1024 seek=8 status=noxfer
sync
sleep 1
losetup -d $LOOP
sleep 1

# 2048 (start) x 512 (block size) = where to mount partition
losetup -o 1048576 $LOOP debian_rootfs.raw
sleep 4

# create filesystem
mkfs.ext4 $LOOP

# tune filesystem
tune2fs -o journal_data_writeback $LOOP

# label it
e2label $LOOP "Debian"

# create mount point and mount image 
mkdir -p $DEST/output/sdcard/
mount -t ext4 $LOOP $DEST/output/sdcard/

echo "------ Install basic filesystem"
# install base system
debootstrap --no-check-gpg --arch=armhf --foreign $RELEASE $DEST/output/sdcard/
# we need this
cp /usr/bin/qemu-arm-static $DEST/output/sdcard/usr/bin/
# enable arm binary format so that the cross-architecture chroot environment will work
test -e /proc/sys/fs/binfmt_misc/qemu-arm || update-binfmts --enable qemu-arm
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
Debian GNU/Linux $VERSION

EOT

# update /etc/motd
rm $DEST/output/sdcard/etc/motd
touch $DEST/output/sdcard/etc/motd

# choose proper apt list
cp $SRC/config/sources.list.$RELEASE $DEST/output/sdcard/etc/apt/sources.list

#cat <<EOT > $DEST/output/sdcard/etc/apt/sources.list
# your custom repo
#EOT

# update, fix locales
chroot $DEST/output/sdcard /bin/bash -c "apt-get update"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install locales makedev"
sed -i "s/^# $DEST_LANG/$DEST_LANG/" $DEST/output/sdcard/etc/locale.gen
chroot $DEST/output/sdcard /bin/bash -c "locale-gen $DEST_LANG"
chroot $DEST/output/sdcard /bin/bash -c "export LANG=$DEST_LANG LANGUAGE=$DEST_LANG DEBIAN_FRONTEND=noninteractive"
chroot $DEST/output/sdcard /bin/bash -c "update-locale LANG=$DEST_LANG LANGUAGE=$DEST_LANG LC_MESSAGES=POSIX"

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

# script to show boot splash
cp $SRC/scripts/bootsplash $DEST/output/sdcard/etc/init.d/bootsplash
# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/bootsplash"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d bootsplash defaults" 

# scripts for autoresize at first boot from cubian
cd $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-resize2fs $DEST/output/sdcard/etc/init.d
cp $SRC/scripts/cubian-firstrun $DEST/output/sdcard/etc/init.d

# script to install to NAND & SATA and kernel switchers
cp $SRC/scripts/2next.sh $DEST/output/sdcard/root
cp $SRC/scripts/2current.sh $DEST/output/sdcard/root
cp $SRC/scripts/nand-install.sh $DEST/output/sdcard/root
cp $SRC/scripts/sata-install.sh $DEST/output/sdcard/root
cp $SRC/bin/nand1-cubietruck-debian-boot.tgz $DEST/output/sdcard/root
cp $SRC/bin/ramlog_2.0.0_all.deb $DEST/output/sdcard/tmp

# bluetooth device enabler 
cp $SRC/bin/brcm_patchram_plus $DEST/output/sdcard/usr/local/bin
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /usr/local/bin/brcm_patchram_plus"
cp $SRC/scripts/brcm40183 $DEST/output/sdcard/etc/default
cp $SRC/scripts/brcm40183-patch $DEST/output/sdcard/etc/init.d
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/brcm40183-patch"
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d brcm40183-patch defaults" 

# install custom bashrc
cat $SRC/scripts/bashrc >> $DEST/output/sdcard/etc/bash.bashrc 

# make it executable
chroot $DEST/output/sdcard /bin/bash -c "chmod +x /etc/init.d/cubian-*"
# and startable on boot
chroot $DEST/output/sdcard /bin/bash -c "update-rc.d cubian-firstrun defaults" 
echo "Installing aditional applications"

# what to install
PAKETKI=$PAKETKI" u-boot-tools makedev libfuse2 libc6 libnl-3-dev bluetooth libbluetooth3 libbluetooth-dev lirc alsa-utils netselect-apt sysfsutils hddtemp bc figlet toilet screen hdparm libfuse2 ntfs-3g bash-completion lsof sudo git hostapd dosfstools htop openssh-server ca-certificates module-init-tools dhcp3-client udev ifupdown iproute iputils-ping ntp rsync usbutils pciutils wireless-tools wpasupplicant procps parted cpufrequtils unzip bridge-utils"

# some packets are different in jessie
if [ "$RELEASE" = "jessie" ]; then
PAKETKI="${PAKETKI//dhcp3-client/isc-dhcp-client}"
fi

chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install $PAKETKI"
# removed in 2.4 #chroot $DEST/output/sdcard /bin/bash -c "apt-get -qq -y install console-setup console-data"
chroot $DEST/output/sdcard /bin/bash -c "apt-get -y clean"

# change dynamic motd
ZAMENJAJ='echo "" > /var/run/motd.dynamic'
ZAMENJAJ=$ZAMENJAJ"\n   if [ \$(cat /proc/meminfo | grep MemTotal | grep -o '[0-9]\\\+') -ge 1531749 ]; then"
ZAMENJAJ=$ZAMENJAJ"\n           toilet -f standard -F metal  \"Cubietruck\" >> /var/run/motd.dynamic"
ZAMENJAJ=$ZAMENJAJ"\n   else"
ZAMENJAJ=$ZAMENJAJ"\n           toilet -f standard -F metal  \"Cubieboard\" >> /var/run/motd.dynamic"
ZAMENJAJ=$ZAMENJAJ"\n   fi"
ZAMENJAJ=$ZAMENJAJ"\n   echo \"\" >> /var/run/motd.dynamic"
sed -e s,"# Update motd","$ZAMENJAJ",g 	-i $DEST/output/sdcard/etc/init.d/motd
sed -e s,"uname -snrvm > /var/run/motd.dynamic","",g  -i $DEST/output/sdcard/etc/init.d/motd

# copy lirc configuration
cp $DEST/sunxi-lirc/lirc_init_files/hardware.conf $DEST/output/sdcard/etc/lirc
cp $DEST/sunxi-lirc/lirc_init_files/init.d_lirc $DEST/output/sdcard/etc/init.d/lirc

# ramlog
chroot $DEST/output/sdcard /bin/bash -c "dpkg -i /tmp/ramlog_2.0.0_all.deb"
sed -e 's/TMPFS_RAMFS_SIZE=/TMPFS_RAMFS_SIZE=256m/g' -i $DEST/output/sdcard/etc/default/ramlog
sed -e 's/# Required-Start:    $remote_fs $time/# Required-Start:    $remote_fs $time ramlog/g' -i $DEST/output/sdcard/etc/init.d/rsyslog 
sed -e 's/# Required-Stop:     umountnfs $time/# Required-Stop:     umountnfs $time ramlog/g' -i $DEST/output/sdcard/etc/init.d/rsyslog   

# console
chroot $DEST/output/sdcard /bin/bash -c "export TERM=linux" 

# Change Time zone data
echo $TZDATA > $DEST/output/sdcard/etc/timezone
chroot $DEST/output/sdcard /bin/bash -c "dpkg-reconfigure -f noninteractive tzdata"

# configure MIN / MAX Speed for cpufrequtils
sed -e 's/MIN_SPEED="0"/MIN_SPEED="480000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/MAX_SPEED="0"/MAX_SPEED="1010000"/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils
sed -e 's/ondemand/interactive/g' -i $DEST/output/sdcard/etc/init.d/cpufrequtils

# eth0 should run on a dedicated processor
sed -e 's/exit 0//g' -i $DEST/output/sdcard/etc/rc.local
cat >> $DEST/output/sdcard/etc/rc.local <<"EOF"
echo 2 > /proc/irq/$(cat /proc/interrupts | grep eth0 | cut -f 1 -d ":" | tr -d " ")/smp_affinity
exit 0
EOF

# set root password
chroot $DEST/output/sdcard /bin/bash -c "(echo $ROOTPWD;echo $ROOTPWD;) | passwd root" 
# force password change upon first login 
chroot $DEST/output/sdcard /bin/bash -c "chage -d 0 root" 

if [ "$RELEASE" = "jessie" ]; then
# enable root login for latest ssh on jessie
sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' $DEST/output/sdcard/etc/ssh/sshd_config || fail
fi

# set hostname 
echo $HOST > $DEST/output/sdcard/etc/hostname

# set hostname in hosts file
cat > $DEST/output/sdcard/etc/hosts <<EOT
127.0.0.1   localhost cubie
::1         localhost cubie ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOT

# change default I/O scheduler, noop for flash media and SSD, cfq for mechanical drive
cat <<EOT >> $DEST/output/sdcard/etc/sysfs.conf
block/mmcblk0/queue/scheduler = noop
block/sda/queue/scheduler = cfq
EOT

# load modules
cat <<EOT >> $DEST/output/sdcard/etc/modules
hci_uart
gpio_sunxi
bt_gpio
wifi_gpio
rfcomm
hidp
lirc_gpio
sunxi_lirc
bcmdhd
sunxi_ss
# if you want access point mode, load wifi module this way: bcmdhd op_mode=2
# and edit /etc/init.d/hostapd change DAEMON_CONF=/etc/hostapd.conf ; edit your wifi net settings in hostapd.conf ; reboot
EOT
# create copy
cp $DEST/output/sdcard/etc/modules $DEST/output/sdcard/etc/modules.current
# create for next
touch $DEST/output/sdcard/etc/modules.next


# create interfaces configuration
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces
auto eth0
allow-hotplug eth0
iface eth0 inet dhcp
#        hwaddress ether # if you want to set MAC manually
#        pre-up /sbin/ifconfig eth0 mtu 3838 # setting MTU for DHCP, static just: mtu 3838
#auto wlan0
#allow-hotplug wlan0
#iface wlan0 inet dhcp
#    wpa-ssid SSID 
#    wpa-psk xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# to generate proper encrypted key: wpa_passphrase yourSSID yourpassword
EOT


# create interfaces if you want to have AP. /etc/modules must be: bcmdhd op_mode=2
cat <<EOT >> $DEST/output/sdcard/etc/network/interfaces.hostapd
auto lo br0
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet manual

allow-hotplug wlan0
iface wlan0 inet manual

iface br0 inet dhcp
bridge_ports eth0 wlan0
hwaddress ether # will be added at first boot
EOT

# add noatime to root FS
echo "/dev/mmcblk0p1  /           ext4    defaults,noatime,nodiratime,data=writeback,commit=600,errors=remount-ro        0       0" >> $DEST/output/sdcard/etc/fstab

# flash media tunning
sed -e 's/#RAMTMP=no/RAMTMP=yes/g' -i $DEST/output/sdcard/etc/default/tmpfs
sed -e 's/#RUN_SIZE=10%/RUN_SIZE=128M/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#LOCK_SIZE=/LOCK_SIZE=/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#SHM_SIZE=/SHM_SIZE=128M/g' -i $DEST/output/sdcard/etc/default/tmpfs 
sed -e 's/#TMP_SIZE=/TMP_SIZE=1G/g' -i $DEST/output/sdcard/etc/default/tmpfs 

# enable serial console (Debian/sysvinit way)
echo T0:2345:respawn:/sbin/getty -L ttyS0 115200 vt100 >> $DEST/output/sdcard/etc/inittab

# uncompress kernel
cd $DEST/output/sdcard/
ls ../*.tar | xargs -i tar xf {}
rm $DEST/output/*.md5
rm $DEST/output/*.tar

# remove false links to the kernel source
find $DEST/output/sdcard/lib/modules -type l -exec rm -f {} \;

# USB redirector tools http://www.incentivespro.com
cd $DEST
wget http://www.incentivespro.com/usb-redirector-linux-arm-eabi.tar.gz
tar xvfz usb-redirector-linux-arm-eabi.tar.gz
rm usb-redirector-linux-arm-eabi.tar.gz
cd $DEST/usb-redirector-linux-arm-eabi/files/modules/src/tusbd
make $CTHREADS ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KERNELDIR=$DEST/linux-sunxi/
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
# not started by default ----- update.rc rc.usbsrvd defaults
# chroot $DEST/output/sdcard /bin/bash -c "update-rc.d rc.usbsrvd defaults"

# hostapd from testing binary replace.
cd $DEST/output/sdcard/usr/sbin/
tar xvfz $SRC/bin/hostapd23.tgz
cp $SRC/config/hostapd.conf $DEST/output/sdcard/etc/

# temper binary for USB temp meter
cd $DEST/output/sdcard/usr/local/bin
tar xvfz $SRC/bin/temper.tgz

# sunxi-tools
cd $DEST/sunxi-tools
make clean && make $CTHREADS 'fex2bin' CC=arm-linux-gnueabihf-gcc && make $CTHREADS 'bin2fex' CC=arm-linux-gnueabihf-gcc && make $CTHREADS 'nand-part' CC=arm-linux-gnueabihf-gcc
cp fex2bin $DEST/output/sdcard/usr/bin/ 
cp bin2fex $DEST/output/sdcard/usr/bin/
cp nand-part $DEST/output/sdcard/usr/bin/
sync
sleep 5
# cleanup 
# unmount proc, sys and dev from chroot
umount -l $DEST/output/sdcard/dev/pts
umount -l $DEST/output/sdcard/dev
umount -l $DEST/output/sdcard/proc
umount -l $DEST/output/sdcard/sys

# let's create nice file name
VERSION="${VERSION// /_}"
VGA=$VERSION"_vga"
HDMI=$VERSION"_hdmi"
#####

sleep 3
killall ntpd

killall dbus-daemon

sleep 2

rm $DEST/output/sdcard/usr/bin/qemu-arm-static 
# umount images 
umount -l $DEST/output/sdcard/ 

losetup -d $LOOP

cp $DEST/output/debian_rootfs.raw $DEST/output/$HDMI.raw
cd $DEST/output/
# creating MD5 sum
md5sum $HDMI.raw > $HDMI.md5
zip $HDMI.zip $HDMI.*
rm $HDMI.raw $HDMI.md5

# let's create VGA version
LOOP=$(losetup -f)
losetup -o 1048576 $LOOP $DEST/output/debian_rootfs.raw
mount $LOOP $DEST/output/sdcard/
sed -e 's/ct-hdmi.bin/ct-vga.bin/g' -i $DEST/output/sdcard/boot/uEnv.ct
sed -e 's/cb2-hdmi.bin/cb2-vga.bin/g' -i $DEST/output/sdcard/boot/uEnv.cb2
umount -l $DEST/output/sdcard/ 
losetup -d $LOOP
mv $DEST/output/debian_rootfs.raw $DEST/output/$VGA.raw
cd $DEST/output/
# creating MD5 sum
md5sum $VGA.raw > $VGA.md5
zip $VGA.zip $VGA.*
rm $VGA.raw $VGA.md5
end=`date +%s`
runtime=$((end-start))
echo "Runtime $runtime sec."
