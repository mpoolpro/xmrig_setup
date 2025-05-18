#!/bin/bash

VERSION=2.11

# printing greetings

echo "mpool mining setup script v$VERSION."
echo "(please report issues to support@mpool.pro email with full output of this script with extra \"-x\" \"bash\" option)"
echo

if [ "$(id -u)" == "0" ]; then
  echo "WARNING: Generally it is not advised to run this script under root"
fi

# command line arguments
WALLET=$1
EMAIL=$2 # this one is optional

# checking prerequisites

if [ -z $WALLET ]; then
  echo "Script usage:"
  echo "> setup_mpool_miner.sh <wallet address> [<your email address>]"
  echo "ERROR: Please specify your wallet address"
  exit 1
fi

WALLET_BASE=`echo $WALLET | cut -f1 -d"."`
if [ ${#WALLET_BASE} != 106 -a ${#WALLET_BASE} != 95 ]; then
  echo "ERROR: Wrong wallet base address length (should be 106 or 95): ${#WALLET_BASE}"
  exit 1
fi

if [ -z $HOME ]; then
  echo "ERROR: Please define HOME environment variable to your home directory"
  exit 1
fi

if [ ! -d $HOME ]; then
  echo "ERROR: Please make sure HOME directory $HOME exists or set it yourself using this command:"
  echo '  export HOME=<dir>'
  exit 1
fi

if ! type curl >/dev/null; then
  echo "ERROR: This script requires \"curl\" utility to work correctly"
  exit 1
fi

if ! type lscpu >/dev/null; then
  echo "WARNING: This script requires \"lscpu\" utility to work correctly"
fi

# calculating projected hash rate

CPU_THREADS=$(nproc)
EXP_MONERO_HASHRATE=$(( CPU_THREADS * 700 / 1000))
if [ -z $EXP_MONERO_HASHRATE ]; then
  echo "ERROR: Can't compute projected Monero CN hashrate"
  exit 1
fi

# printing intentions

echo "I will download, setup and run in background mpool CPU miner."
echo "If needed, miner in foreground can be started by \$HOME/mpool/miner.sh script."
echo "Mining will happen to \$WALLET wallet."
if [ ! -z $EMAIL ]; then
  echo "(and $EMAIL email as password to modify wallet options later at https://mpool.pro site)"
fi
echo

if ! sudo -n true 2>/dev/null; then
  echo "Since I can't do passwordless sudo, mining in background will start from your \$HOME/.profile file first time you login this host after reboot."
else
  echo "Mining in background will be performed using mpool_miner systemd service."
fi

echo
echo "JFYI: This host has $CPU_THREADS CPU threads, so projected Monero hashrate is around $EXP_MONERO_HASHRATE KH/s."
echo

echo "Sleeping for 15 seconds before continuing (press Ctrl+C to cancel)"
sleep 15
echo
echo

# start doing stuff: preparing miner

echo "[*] Removing previous mpool miner (if any)"
if sudo -n true 2>/dev/null; then
  sudo systemctl stop mpool_miner.service
fi
killall -9 xmrig

echo "[*] Removing \$HOME/mpool directory"
rm -rf $HOME/mpool

echo "[*] Downloading mpool advanced version of xmrig to /tmp/xmrig.tar.gz"
if ! curl -L --progress-bar "https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/xmrig.tar.gz" -o /tmp/xmrig.tar.gz; then
  echo "ERROR: Can't download https://raw.githubusercontent.com/mpoolpro/xmrig_setup/master/xmrig.tar.gz file to /tmp/xmrig.tar.gz"
  exit 1
fi

echo "[*] Unpacking /tmp/xmrig.tar.gz to \$HOME/mpool"
[ -d $HOME/mpool ] || mkdir $HOME/mpool
if ! tar xf /tmp/xmrig.tar.gz -C $HOME/mpool; then
  echo "ERROR: Can't unpack /tmp/xmrig.tar.gz to \$HOME/mpool directory"
  exit 1
fi
rm /tmp/xmrig.tar.gz

echo "[*] Checking if advanced version of \$HOME/mpool/xmrig works fine (and not removed by antivirus software)"
sed -i 's/"donate-level": *[^,]*,/"donate-level": 1,/' $HOME/mpool/config.json
$HOME/mpool/xmrig --help >/dev/null
if (test $? -ne 0); then
  if [ -f $HOME/mpool/xmrig ]; then
    echo "WARNING: Advanced version of \$HOME/mpool/xmrig is not functional"
  else 
    echo "WARNING: Advanced version of \$HOME/mpool/xmrig was removed by antivirus (or some other problem)"
  fi

  echo "[*] Looking for the latest version of Monero miner"
  LATEST_XMRIG_RELEASE=`curl -s https://github.com/xmrig/xmrig/releases/latest  | grep -o '".*"' | sed 's/"//g'`
  LATEST_XMRIG_LINUX_RELEASE="https://github.com"`curl -s $LATEST_XMRIG_RELEASE | grep xenial-x64.tar.gz\" |  cut -d \" -f2`

  echo "[*] Downloading \$LATEST_XMRIG_LINUX_RELEASE to /tmp/xmrig.tar.gz"
  if ! curl -L --progress-bar $LATEST_XMRIG_LINUX_RELEASE -o /tmp/xmrig.tar.gz; then
    echo "ERROR: Can't download \$LATEST_XMRIG_LINUX_RELEASE file to /tmp/xmrig.tar.gz"
    exit 1
  fi

  echo "[*] Unpacking /tmp/xmrig.tar.gz to \$HOME/mpool"
  if ! tar xf /tmp/xmrig.tar.gz -C $HOME/mpool --strip=1; then
    echo "WARNING: Can't unpack /tmp/xmrig.tar.gz to \$HOME/mpool directory"
  fi
  rm /tmp/xmrig.tar.gz

  echo "[*] Checking if stock version of \$HOME/mpool/xmrig works fine (and not removed by antivirus software)"
  sed -i 's/"donate-level": *[^,]*,/"donate-level": 0,/' $HOME/mpool/config.json
  $HOME/mpool/xmrig --help >/dev/null
  if (test $? -ne 0); then 
    if [ -f $HOME/mpool/xmrig ]; then
      echo "ERROR: Stock version of \$HOME/mpool/xmrig is not functional too"
    else 
      echo "ERROR: Stock version of \$HOME/mpool/xmrig was removed by antivirus too"
    fi
    exit 1
  fi
fi

echo "[*] Miner \$HOME/mpool/xmrig is OK"

PASS=`hostname | cut -f1 -d"." | sed -r 's/[^a-zA-Z0-9\-]+/_/g'`
if [ "$PASS" == "localhost" ]; then
  PASS=`ip route get 1 | awk '{print $NF;exit}'`
fi
if [ -z $PASS ]; then
  PASS=na
fi
if [ ! -z $EMAIL ]; then
  PASS="$PASS:$EMAIL"
fi

# configure pool to world.mpool.pro:4242 only
sed -i 's/"url": *"[^"]*",/"url": "world.mpool.pro:4242",/' $HOME/mpool/config.json
sed -i 's/"user": *"[^"]*",/"user": "'$WALLET'",/' $HOME/mpool/config.json
sed -i 's/"pass": *"[^"]*",/"pass": "'$PASS'",/' $HOME/mpool/config.json
sed -i 's/"max-cpu-usage": *[^,]*,/"max-cpu-usage": 100,/' $HOME/mpool/config.json
sed -i 's#"log-file": *null,#"log-file": "'$HOME/mpool/xmrig.log'",#' $HOME/mpool/config.json
sed -i 's/"syslog": *[^,]*,/"syslog": true,/' $HOME/mpool/config.json

cp $HOME/mpool/config.json $HOME/mpool/config_background.json
sed -i 's/"background": *false,/"background": true,/' $HOME/mpool/config_background.json

# preparing script

echo "[*] Creating \$HOME/mpool/miner.sh script"
cat >$HOME/mpool/miner.sh <<EOL
#!/bin/bash
if ! pidof xmrig >/dev/null; then
  nice \$HOME/mpool/xmrig \$*
else
  echo "Monero miner is already running in the background. Refusing to run another one."
  echo "Run \"killall xmrig\" or \"sudo killall xmrig\" if you want to remove background miner first."
fi
EOL

chmod +x $HOME/mpool/miner.sh

# preparing background start

if ! sudo -n true 2>/dev/null; then
  if ! grep mpool/miner.sh $HOME/.profile >/dev/null; then
    echo "[*] Adding \$HOME/mpool/miner.sh script to \$HOME/.profile"
    echo "\$HOME/mpool/miner.sh --config=\$HOME/mpool/config_background.json >/dev/null 2>&1" >>$HOME/.profile
  else 
    echo "Looks like \$HOME/mpool/miner.sh script is already in the \$HOME/.profile"
  fi
  echo "[*] Running miner in the background (see logs in \$HOME/mpool/xmrig.log file)"
  /bin/bash $HOME/mpool/miner.sh --config=$HOME/mpool/config_background.json >/dev/null 2>&1
else

  if [[ $(grep MemTotal /proc/meminfo | awk '{print $2}') > 3500000 ]]; then
    echo "[*] Enabling huge pages"
    echo "vm.nr_hugepages=$((1168+$(nproc)))" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -w vm.nr_hugepages=$((1168+$(nproc)))
  fi

  if ! type systemctl >/dev/null; then

    echo "[*] Running miner in the background (see logs in \$HOME/mpool/xmrig.log file)"
    /bin/bash $HOME/mpool/miner.sh --config=$HOME/mpool/config_background.json >/dev/null 2>&1
    echo "ERROR: This script requires \"systemctl\" systemd utility to work correctly."
    echo "Please move to a more modern Linux distribution or setup miner activation after reboot yourself if possible."

  else

    echo "[*] Creating mpool_miner systemd service"
    cat >/tmp/mpool_miner.service <<EOL
[Unit]
Description=mpool miner service

[Service]
ExecStart=$HOME/mpool/xmrig --config=$HOME/mpool/config.json
Restart=always
Nice=10
CPUWeight=1

[Install]
WantedBy=multi-user.target
EOL
    sudo mv /tmp/mpool_miner.service /etc/systemd/system/mpool_miner.service
    echo "[*] Starting mpool_miner systemd service"
    sudo killall xmrig 2>/dev/null
    sudo systemctl daemon-reload
    sudo systemctl enable mpool_miner.service
    sudo systemctl start mpool_miner.service
    echo "To see miner service logs run \"sudo journalctl -u mpool_miner -f\" command"
  fi
fi

echo ""
echo "NOTE: If you are using shared VPS it is recommended to avoid 100% CPU usage produced by the miner or you will be banned"
if [ "$CPU_THREADS" -lt "4" ]; then
  echo "HINT: Please execute these or similar commands under root to limit miner to 75% CPU usage:"
  echo "sudo apt-get update; sudo apt-get install -y cpulimit"
  echo "sudo cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b"
  if [ "`tail -n1 /etc/rc.local`" != "exit 0" ]; then
    echo "sudo sed -i -e '\$acpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  else
    echo "sudo sed -i -e '\$i \\cpulimit -e xmrig -l $((75*$CPU_THREADS)) -b\\n' /etc/rc.local"
  fi
else
  echo "HINT: Please execute these commands and reboot your VPS after that to limit miner to 75% CPU usage:"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/mpool/config.json"
  echo "sed -i 's/\"max-threads-hint\": *[^,]*,/\"max-threads-hint\": 75,/' \$HOME/mpool/config_background.json"
fi
echo ""

echo "[*] Setup complete"
