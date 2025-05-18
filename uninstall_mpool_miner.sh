#!/bin/bash

VERSION=1.0

# printing greetings

echo "mpool mining uninstall script v$VERSION."
echo "(please report issues to support@mpool.pro email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists"
  exit 1
fi

echo "[*] Removing mpool miner"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop mpool_miner.service
  sudo systemctl disable mpool_miner.service
  rm -f /etc/systemd/system/mpool_miner.service
  sudo systemctl daemon-reload
  sudo systemctl reset-failed
fi

sed -i '/mpool/d' $HOME/.profile
killall -9 xmrig

echo "[*] Removing $HOME/mpool directory"
rm -rf $HOME/mpool

echo "[*] Uninstall complete"

