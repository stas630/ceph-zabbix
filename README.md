# ceph-zabbix

A zabbix probe to get performance counters of ceph (Luminous 12.2+)


Installation
============

Install jq:
      sudo apt install jq

Copy the script into /etc/zabbix

Then, correct the following zabbix parameter in /etc/zabbix/zabbix_agentd.conf.d/ceph.conf for instance:
      UserParameter=ceph.health, /etc/zabbix/scripts/ceph-data.sh health client_host_name_in_zabbix
      UserParameter=ceph-mon-discovery, /etc/zabbix/scripts/ceph-data.sh mons client_host_name_in_zabbix
      UserParameter=ceph-pools-discovery, /etc/zabbix/scripts/ceph-data.sh pools client_host_name_in_zabbix
      UserParameter=ceph-osd-discovery, /etc/zabbix/scripts/ceph-data.sh osds client_host_name_in_zabbix

Correct /etc/zabbix/zabbix_agentd.conf.exmple and copy:
      cp /etc/zabbix/zabbix_agentd.conf.exmple /etc/zabbix/zabbix_agentd.conf

Finally in zabbix setup the discovery rule and related items you need.# ceph-zabbix
