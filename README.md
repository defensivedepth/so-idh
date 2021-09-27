### Security Onion - Intrusion Detection Honeypot Node

This project will convert a Forward Node into an Intrusion Detection Honeypot (IDH) Node.
It is experimental and a work in progress.

### Installation

This script requires a distributed grid with at least one Forward node.

Clone this repo onto the Manager:

`git clone https://github.com/defensivedepth/so-idh.git`

Then run the installation script:

`sudo sh idh-setup.sh`

You will be prompted to rerun the installation script, passing in the hostname of a Forward node as a parameter:

`sudo sh idh-setup.sh <Forwad Node Hostname>`
