#


### Disable the following services on the Forward Node
### Steno, Strelka (Disabled via minion pillar), Zeek, Suricata (Possibly via Top)



# Setup IDH Firewall rules

sudo so-firewall addportgroup idh
sudo so-firewall addport idh tcp 21

sudo so-firewall addhostgroup idh-hosts
sudo so-firewall includehost idh-hosts 0.0.0.0

Insert the following into the minion SLS:

firewall:
  assigned_hostgroups:
    chain:
      INPUT:
        hostgroups:
          idh-hosts:
            portgroups:
              - portgroups.idh

sudo salt-call state.apply firewall
