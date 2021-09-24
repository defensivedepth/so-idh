# Originally developed by Josh Brower, @DefensiveDepth
# Released under the MIT License, Copyright (c) 2021 Josh Brower
#
# VERSION .1
# 
# This experimental script will convert a Forward \
# node into an Intrusion Detection Honeypot (IDH) node.
#
# This script should be run with sudo on the Manager.
#
# <-- Warnings and Disclaimers -->
# This is experimental and a work in progress.
# This is intended to build a quick prototype SO IDH.

. /usr/sbin/so-common
SETUPLOG=/root/idh-setup.log

function check_exit_code {
  if [ $? -ne 0 ]; then
    echo ""
    echo "Error detected during Setup, please check $SETUPLOG for details." 
    exit 1
  fi
}

# Check to see if this is a Manager 
echo ""
require_manager
echo ""

# Check to see if the Manager is the minimum version needed (2.3.80)
INSTALLEDVERSION=$(cat /etc/soversion)
vercheck() {
    [  "$1" = "`echo -e "$1\n$2" | sort -V | tail -n1`" ]
}
vercheck $INSTALLEDVERSION 2.2.80 && printf "Version check succeeded\n" || \
 { echo "Minimum version not installed: 2.3.80 or greater required. Exiting..."; exit 1; }

printf "\n$banner\n"
printf "This experimental script will convert a Forward Node\n\
into an Intrusion Detection Honeypot (IDH) Node.\n\
It is experimental and a work in progress.\n"
echo $banner
read -p "Do you want to continue? (Y/N) " -n 1 -r
echo    
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    exit 1
fi

# Usage Instructions
if [ $# -lt 1 ]; then
  echo ""
  echo "No Input Found --> Usage: $0 <forward_node_hostname>"
  echo ""
  echo "--Available Forward Nodes--"
  echo ""
  salt "*_sensor" test.ping
  echo ""
  exit 1
fi

# Validate the given hostname is a legit Forward node
if [[ "$1" == *"_sensor"* ]]; then
    sensor_saltid=${1}
else
    sensor_saltid=${1}_sensor
fi

node_exists=$(salt "$sensor_saltid" test.ping)

if [[ "$node_exists" == *"True"* ]]; then
   echo ""
   echo "Specified Forward Node found & is up... Continuing."
   echo ""
else
    echo ""
    echo "Error - Hostname does not match any Forward Nodes in the Grid or the Node is down"
    echo ""
    echo "Note: Hostname is case sensitive."
    echo ""
    exit
fi

# Disable Sensor services on the Forward Node
minion_sls=/opt/so/saltstack/local/pillar/minions/${sensor_saltid}.sls
if grep -q "suricata" < "$minion_sls"; then
  echo ""
  echo "Sensor services already disabled - skipping this step..."
else
  echo ""
  echo "Disabling Sensor services on the Forward Node..."
  # Delete steno pillar if found
  sed -i '/steno/,+1 d' $minion_sls
  # Add disabled services pillars
  cat ./files/disable-services >> $minion_sls
  salt "$sensor_saltid" state.apply suricata,zeek,pcap queue=True >> "$SETUPLOG" 2>&1
fi

# Copy over the IDH Salt state & Apply it to the Forward Node
mkdir -p /opt/so/saltstack/local/salt/idh/
cp -rp ./salt-state/* /opt/so/saltstack/local/salt/idh/
salt-cp "$sensor_saltid" -C ./salt-state/* /opt/so/saltstack/local/salt/idh/  >> "$SETUPLOG" 2>&1
check_exit_code 
echo "Applying the IDH state on the Forward Node - this will take some time..."
salt "$sensor_saltid" state.apply idh queue=True >> "$SETUPLOG" 2>&1
check_exit_code 

# Setup IDH Firewall rules
if grep -q "firewall" < "$minion_sls"; then
  echo ""
  echo "Firewall rules already included in minion file - skipping this step..."
else
  so-firewall addportgroup idh
  so-firewall addport idh tcp 2222
  so-firewall addport idh tcp 5900
  so-firewall addhostgroup idh-hosts
  so-firewall includehost idh-hosts 0.0.0.0/0
  cat ./files/firewall-config >> $minion_sls
  salt "$sensor_saltid" state.apply firewall queue=True  >> "$SETUPLOG" 2>&1
fi
check_exit_code

# Setup Filebeat Pipeline
if grep -q "filebeat" < "$minion_sls"; then
  echo ""
  echo "Filebeat config already included in minion file - skipping this step..."
else
  cat ./files/filebeat-config >> $minion_sls
  salt "$sensor_saltid" state.apply filebeat queue=True  >> "$SETUPLOG" 2>&1
fi
check_exit_code

# Import Plays
cp -r ./files/*.yml /opt/so/conf/soctopus/sigma-import/
so-playbook-import True  >> "$SETUPLOG" 2>&1
check_exit_code

IDHIP=$(salt "$sensor_saltid" pillar.get sensor:mainip --out json | jq -r '.[]')

echo ""
echo "-=== IDH Setup Complete on $sensor_saltid - $IDHIP ===-"
echo ""
echo "Default IDH config:"
echo "- SSH on TCP/2222 accessible 0.0.0.0/0"
echo "- VNC on TCP/5900 accessible 0.0.0.0/0"
printf "\nOpenCanary config is on the IDH Node in /opt/so/conf/idh/."
printf "\nRun so-idh-apply-config on the Manager to apply config changes."
printf "\nIf a new port is needed, add that as a parameter:"
printf "\n so-idh-apply-config <Port Number>"
printf "\n\nGood luck & have fun!\n\n"