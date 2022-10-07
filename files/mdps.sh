#!/bin/bash
source /etc/profile.d/CP.sh
clish -c "lock database override"
clish -c "set mdps interface eth0 management on"
clish -c "set mdps interface eth0 sync on"
clish -c "set mdps mgmt plane on" <<< $'y\ny'
clish -c "set mdps environment mplane"
clish -c "set static-route default nexthop gateway address 192.168.100.1 on"
clish -s -c "add mdps task address 192.168.100.23"
shutdown -r -t 5 now
