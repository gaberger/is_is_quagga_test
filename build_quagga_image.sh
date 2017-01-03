#!/bin/bash

set -ex

lxc launch ubuntu netdev-base-temp
sleep 10
lxc file push install_quagga.sh netdev-base-temp/home/ubuntu/install_quagga.sh
lxc exec netdev-base-temp -- /home/ubuntu/install_quagga.sh
lxc exec netdev-base-temp -- adduser quagga --system || true
lxc exec netdev-base-temp -- addgroup quagga || true
lxc file push quagga netdev-base-temp/etc/init.d/quagga
lxc exec netdev-base-temp -- chown root:root /etc/init.d/quagga
lxc exec netdev-base-temp -- chmod 755 /etc/init.d/quagga
lxc file push debian.conf netdev-base-temp/usr/local/etc/debian.conf
lxc exec netdev-base-temp -- chown -R quagga:quagga /usr/local/etc/debian.conf
lxc file push daemons netdev-base-temp/usr/local/etc/daemons
lxc file push quagga.pamd netdev-base-temp/etc/pam.d/quagga
lxc exec netdev-base-temp -- chown -R quagga:quagga /usr/local/etc
lxc file push is_is_agent.py netdev-base-temp/home/ubuntu/is_is_agent.py
lxc stop netdev-base-temp
sleep 5
lxc publish netdev-base-temp --alias netdev-base
lxc delete netdev-base-temp
