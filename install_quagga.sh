#/bin/bash
set -e
echo "deb [trusted=yes] https://repo.iovisor.org/apt/xenial xenial-nightly main" | sudo tee /etc/apt/sources.list.d/iovisor.list
sudo apt-get -y update
sudo apt-get -y install g++ texinfo
sudo apt-get -y install libreadline6 libreadline6-dev
sudo apt-get -y install build-essential git tree bcc-tools
sudo apt-get -y install linux-headers-`uname -r`
sudo apt-get -y install --reinstall linux-image-`uname -r`
wget http://download.savannah.gnu.org/releases/quagga/quagga-1.1.0.tar.gz
tar zxvf quagga-1.1.0.tar.gz
cd quagga-1.1.0
./configure --sysconfdir=/usr/local/etc --with-libpam --enable-vtysh --disable-ospfclient --disable-ipv6 --disable-ripd --disable-ripngd --disable-ospfd  --disable-ospf6d --disable-bgpd
make
make install