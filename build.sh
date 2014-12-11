#!/bin/bash
#
# Created by Igor Pecovnik, www.igorpecovnik.com
#
# Configuration 
#--------------------------------------------------------------------------------------------------------------------------------

BOARD="cubietruck"					# cubietruck = cubieboard2, cubieboard4
BRANCH="default"					# default=3.4.x, mainline=next
RELEASE="wheezy"                                   	# jessie or wheezy
VERSION="${BOARD^} Debian 2.9 $RELEASE"               	# just name
SOURCE_COMPILE="yes"                               	# yes / no
KERNEL_CONFIGURE="yes"					# do you want to change my default configuration
DEST_LANG="en_US.UTF-8"                         	# sl_SI.UTF-8, en_US.UTF-8
TZDATA="Europe/Ljubljana"                         	# Timezone
DEST=$(pwd)/output                      		# Destination
ROOTPWD="1234"                               		# Must be changed @first login
HOST="$BOARD"						# Hostname
USEALLCORES="no"					# Use all CPU cores for compiling
SDSIZE="1000"						# SD image size in MB
FBTFT="no"						# Small TFT support, https://github.com/notro/fbtft

#--------------------------------------------------------------------------------------------------------------------------------
# superuser have to do this
if [ "$UID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

if [ "$BRANCH" == "next" ]; then
	BOARD=$BOARD"-"$BRANCH
fi

# source is where we start the script
SRC=$(pwd)

# get updates of the main build libraries
if [ -d "$SRC/lib" ]; then
	cd $SRC/lib
	git pull 
else
	git clone https://github.com/igorpecovnik/lib lib
fi
cd $SRC

source $SRC/lib/boards.config # Board configuration
source $SRC/lib/common.sh # Functions
source $SRC/lib/main.sh # Main
#--------------------------------------------------------------------------------------------------------------------------------
