#!/usr/bin/python
# -*- coding: utf-8 -*-
#
# Ansible module to manage CheckPoint Firewall (c) 2022
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.
#

from __future__ import (absolute_import, division, print_function)

__metaclass__ = type

ANSIBLE_METADATA = {'metadata_version': '1.0',
                    'status': ['preview'],
                    'supported_by': 'community'}

DOCUMENTATION = """
---
module: custom_set_simple_cluster_member
short_description: add or removes a permission profile to a existing access layer object.
description:
  - Manages simple-cluster member objects on Checkpoint clusters including creating (adding) and removing mebers.
  - All operations are performed over Web Services API.
author: "Jim Oqvist (@chkp-jimo)"
extends_documentation_fragment: check_point.mgmt.checkpoint_commands
"""

EXAMPLES = """
- name: Add cluster member to existing cluster
  custom_set_simple_cluster_member:
    name: cluster1
    members:
      add:
      - name: member3
        ip_address: 17.23.5.4
        one_time_password: abcd
        interfaces:
        - ip_address: 17.23.5.4
          name: eth0
          network_mask: 255.255.255.0
        - ip_address: 1.1.2.43
          name: eth1
          network_mask: 255.255.255.0
        - ip_address: 192.168.1.4
          name: eth2
          network_mask: 255.255.255.0

- name: Remove cluster meber from existing cluster
- name: Add cluster member to existing cluster
  custom_set_simple_cluster_member:
    name: cluster1
    members:
      remove:
      - name: member3
"""

RETURN = """
custom_set_premission_profiles_access_layer:
  description: The checkpoint add-repository-package output.
  returned: always.
  type: dict
"""

from ansible.module_utils.basic import AnsibleModule
from ansible_collections.check_point.mgmt.plugins.module_utils.checkpoint import checkpoint_argument_spec_for_commands, api_command


def main():
    argument_spec = dict(
        name=dict(type='str', required=True),
        members=dict(type='dict', options=dict(
            add=dict(type='list', elements='dict', options=dict(
                name=dict(type='str'),
                interfaces=dict(type='list', elements='dict', options=dict(
                    name=dict(type='str'),
                    anti_spoofing=dict(type='bool'),
                    anti_spoofing_settings=dict(type='dict', options=dict(
                        action=dict(type='str', choices=['prevent', 'detect']),
                        exclude_packets=dict(type='bool'),
                        excluded_network_name=dict(type='str'),
                        excluded_network_uid=dict(type='str'),
                        spoof_tracking=dict(type='str', choices=['none', 'log', 'alert'])
                    )),
                    ip_address=dict(type='str'),
                    ipv4_address=dict(type='str'),
                    ipv6_address=dict(type='str'),
                    network_mask=dict(type='str'),
                    ipv4_network_mask=dict(type='str'),
                    ipv6_network_mask=dict(type='str'),
                    mask_length=dict(type='str'),
                    ipv4_mask_length=dict(type='str'),
                    ipv6_mask_length=dict(type='str'),
                    security_zone=dict(type='bool'),
                    security_zone_settings=dict(type='dict', options=dict(
                        auto_calculated=dict(type='bool'),
                        specific_zone=dict(type='str')
                    )),
                    tags=dict(type='list', elements='str'),
                    topology=dict(type='str', choices=['automatic', 'external', 'internal']),
                    topology_settings=dict(type='dict', options=dict(
                        interface_leads_to_dmz=dict(type='bool'),
                        ip_address_behind_this_interface=dict(type='str', choices=['not defined', 'network defined by the interface ip and net mask',
                                                                                   'network defined by routing', 'specific']),
                        specific_network=dict(type='str')
                    )),
                    color=dict(type='str', choices=['aquamarine', 'black', 'blue', 'crete blue', 'burlywood',
                                                    'cyan', 'dark green', 'khaki', 'orchid', 'dark orange', 'dark sea green', 'pink', 'turquoise', 'dark blue',
                                                    'firebrick', 'brown', 'forest green', 'gold', 'dark gold', 'gray', 'dark gray', 'light green', 'lemon chiffon',
                                                    'coral', 'sea green', 'sky blue', 'magenta', 'purple', 'slate blue', 'violet red', 'navy blue', 'olive',
                                                    'orange', 'red', 'sienna', 'yellow']),
                    comments=dict(type='str'),
                    details_level=dict(type='str', choices=['uid', 'standard', 'full']),
                    ignore_warnings=dict(type='bool'),
                    ignore_errors=dict(type='bool')
                )),
                ip_address=dict(type='str'),
                ipv4_address=dict(type='str'),
                ipv6_address=dict(type='str'),
                one_time_password=dict(type='str', no_log=True),
                tags=dict(type='list', elements='str'),
                color=dict(type='str', choices=['aquamarine', 'black', 'blue', 'crete blue', 'burlywood', 'cyan',
                                                'dark green', 'khaki', 'orchid', 'dark orange', 'dark sea green', 'pink', 'turquoise', 'dark blue', 'firebrick',
                                                'brown', 'forest green', 'gold', 'dark gold', 'gray', 'dark gray', 'light green', 'lemon chiffon', 'coral',
                                                'sea green', 'sky blue', 'magenta', 'purple', 'slate blue', 'violet red', 'navy blue', 'olive', 'orange', 'red',
                                                'sienna', 'yellow']),
                comments=dict(type='str'),
                details_level=dict(type='str', choices=['uid', 'standard', 'full']),
                ignore_warnings=dict(type='bool'),
                ignore_errors=dict(type='bool')
            ))
        )),
        color=dict(type='str', choices=['aquamarine', 'black', 'blue', 'crete blue', 'burlywood', 'cyan', 'dark green',
                                        'khaki', 'orchid', 'dark orange', 'dark sea green', 'pink', 'turquoise', 'dark blue', 'firebrick', 'brown',
                                        'forest green', 'gold', 'dark gold', 'gray', 'dark gray', 'light green', 'lemon chiffon', 'coral', 'sea green',
                                        'sky blue', 'magenta', 'purple', 'slate blue', 'violet red', 'navy blue', 'olive', 'orange', 'red', 'sienna',
                                        'yellow']),
        details_level=dict(type='str', choices=['uid', 'standard', 'full']),
        ignore_warnings=dict(type='bool'),
        ignore_errors=dict(type='bool')
    )
    argument_spec.update(checkpoint_argument_spec_for_commands)

    module = AnsibleModule(argument_spec=argument_spec)
    command = 'set-simple-cluster'

    result = api_command(module, command)
    module.exit_json(**result)


if __name__ == '__main__':
    main()