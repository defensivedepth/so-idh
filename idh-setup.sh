# This is experimental!
# This script will convert a Forward node into an IDH node


. /usr/sbin/so-common

# Check to see if this is a Manager 
echo ""
require_manager

# Usage Instructions
if [ $# -lt 1 ]; then
  echo ""
  echo "No Input Found - Usage: $0 <forward_node_hostname>"
  echo ""
  echo "Available Forward Nodes:"
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
   echo "Forward Node found & is up... Continuing."
   echo ""
else
    echo "Error - Hostname does not match any Forward Nodes in the Grid or the Node is down"
    echo "Note: Hostname is case sensitive."
    echo ""
    exit
fi


# TODO Disable Sensor services on the Forward Node


# Copy IDH Salt state to Forward Node & Apply it
salt-cp "$sensor_saltid" -C ./salt-state/* /opt/so/saltstack/local/idh/
salt "$sensor_saltid" state.apply idh

# Setup IDH Firewall rules
minion_sls=/opt/so/saltstack/local/pillar/minions/${sensor_saltid}.sls
if grep -iq "firewall" <<< "$minion_sls"; then
  echo "Firewall rules already included in minion file - skipping this step..."
else
  so-firewall addportgroup idh
  so-firewall addport idh tcp 2222
  so-firewall addport idh tcp 5900
  so-firewall addhostgroup idh-hosts
  so-firewall includehost idh-hosts 0.0.0.0/0
  cat ./files/firewall-settings >> $minion_sls
  salt "$sensor_saltid" state.apply firewall
fi

# Setup Filebeat Pipeline
if grep -iq "filebeat" <<< "$minion_sls"; then
  echo "Filebeat config already included in minion file - skipping this step..."
else
  cat ./files/filebeat-settings >> $minion_sls
  salt "$sensor_saltid" state.apply filebeat
fi

echo ""
echo "IDH Setup Complete"
echo "Default IDH config:"
echo "- SSH on TCP/2222"
echo "- VNC on TCP/5900"
echo ""