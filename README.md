Cubietruck-Debian
=================

Scripts to create an Image of Debian or only kernel for Cubieboard 2 and Cubietruck

Images, manual and history:

http://www.igorpecovnik.com/2013/12/24/cubietruck-debian-wheezy-sd-card-image/

<a href="https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CUYH2KR36YB7W"><img style="padding:0;" width=74 height=21  src="https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif" alt="Donate!" / border="0"></a>

Read also the FAQ: https://github.com/igorpecovnik/Cubietruck-Debian/wiki/FAQ

Installation steps
------------------
1. <a href=http://releases.ubuntu.com/14.04/>Install Ubuntu 14.04 LTS</a> into your (virtual) PC
2. Login as root and execute:

```shell
sudo apt-get -y install git
cd ~
git clone https://github.com/igorpecovnik/Cubietruck-Debian
chmod +x ./Cubietruck-Debian/build.sh
cd ./Cubietruck-Debian
sudo ./build.sh
```
