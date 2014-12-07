Cubieboard 2 and Cubietruck Debian
================
![](http://www.igorpecovnik.com/wp-content/uploads/2014/11/cubietr1.png)

Script to create bootable SD card image of Debian for Cubieboard 2 and Cubietruck.

[Check build libraries](https://github.com/igorpecovnik/lib)

Prebuild images, support & history
------------------
[http://www.igorpecovnik.com/2013/12/24/cubietruck-debian-wheezy-sd-card-image/](http://www.igorpecovnik.com/2013/12/24/cubietruck-debian-wheezy-sd-card-image/ "Download")

Thank you for your donation
------------------

[![Paypal donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=CUYH2KR36YB7W)

![My bitcoin address](http://www.igorpecovnik.com/wp-content/uploads/2014/10/bitcoinigor.png)

17vT6hV83EQ6rizbWeasfy1tWEzFpzYqEE

DIY
------------------
- [Install Ubuntu 14.10](http://releases.ubuntu.com/14.10/) into your (virtual) PC
- Login as root and execute:
```shell
sudo apt-get -y install git
cd ~
git clone https://github.com/igorpecovnik/Cubietruck-Debian
chmod +x ./Cubietruck-Debian/build.sh
cd ./Cubietruck-Debian
```
edit build.sh and alter configuration

```shell
sudo ./build.sh
```
- Wait around 3h on a 10Mbit line and average desktop computer.
- If build is succesfull you will find zipped image in your **output/output** directory. Unzip and burn with supplied writter or DD (Unix / Mac) to your SD card.
- Boot your Banana :=)
