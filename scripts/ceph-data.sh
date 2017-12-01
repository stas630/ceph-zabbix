#!/bin/sh
#
# ceph-data.sh <mons|osds|pools|health> [client_hostname_in_zabbix]
# 20171201 v1.0 stas630
# sudo apt-get install jq
#
ZBX_CONFIG_AGENT="/etc/zabbix/zabbix_agentd.conf"
# Uncomment if need log
#LOG="/var/log/zabbix-agent/ceph.log"
#
#
HOSTNAME=$2

export PATH=/bin:/usr/bin
TMPS=`mktemp -t zbx-ceph.XXXXXXXXXXX`

case $1 in
  osds)
    ceph osd df tree -f json |\
      jq -r '(.nodes[]|select(.type=="osd")|"\(.name) \(.kb_avail / 1048576)"),
        "ceph.spaceavail \(.summary.total_kb_avail / 1048576)",
        "ceph.spacetotal \(.summary.total_kb / 1048576)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if(NR!=1){ printf "," }
          if($1~/^osd/){
            print "{ \"{#OSD}\":\""$1"\" }"
            print "'$HOSTNAME' ceph.osdspaceavail["$1"] "$2 >"'${TMPS}'"
          }else{
            print "'$HOSTNAME' "$1" "$2 >"'${TMPS}'"
          }
        }
        END{ print "]}" }'
    ceph osd dump -f json |\
      jq -r '(.osds[]| "'${HOSTNAME}' ceph.osdstatus[osd.\(.osd)] \(.up)"),
        "'${HOSTNAME}' ceph.osdcount \(.max_osd)"' >>${TMPS}
  ;;

  pools)
    ceph df -f json |\
      jq -r '.pools[]|"\(.name) \(.stats.max_avail / 1073741824)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if(NR!=1){ printf "," }
          print "{ \"{#POOL}\":\""$1"\" }"
          print "'$HOSTNAME' ceph.poolspaceavail["$1"] "$2 >"'${TMPS}'"
        }
        END{ print "]}" }'
  ;;

  mons)
    ceph mon dump 2>/dev/null -f json |\
      jq -r  'reduce .mons[] as $mon ({rquorum:.quorum,rmons:{}}; . + {rmons:(.rmons+ { ($mon.name):(.rquorum| if index($mon.rank)==null then 0 else 1 end) })} ) |.rmons|to_entries[]|"\(.key) \(.value)"'|\
      awk '
        BEGIN{ print "{\"data\":[" }
        {
          if(NR!=1){ printf "," }
          print "{ \"{#MON}\":\""$1"\" }"
          print "'$HOSTNAME' ceph.monstatus["$1"] "$2 >"'${TMPS}'"
        }
        END{ print "]}" }'
  ;;

  health)
    ceph status -f json |\
      jq -r '
        "\(if .health.status =="HEALTH_OK" then 1 elif .health.status =="HEALTH_WARN" then 2 else 0 end)",
        "ceph.moncount \(.monmap.mons|length)",
        "ceph.pgtotal \(.pgmap.num_pgs)",
        "ceph.activating \(.pgmap.pgs_by_state|map(select(.state_name|contains("activating")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.active \(.pgmap.pgs_by_state|map(select(.state_name|contains("active")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfilling \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfilling")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_toofull \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_toofull")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_unfound \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_unfound")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.backfill_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("backfill_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.clean \(.pgmap.pgs_by_state|map(select(.state_name|contains("clean")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.creating \(.pgmap.pgs_by_state|map(select(.state_name|contains("creating")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.deep \(.pgmap.pgs_by_state|map(select(.state_name|contains("deep")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.degraded \(.pgmap.pgs_by_state|map(select(.state_name|contains("degraded")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.down \(.pgmap.pgs_by_state|map(select(.state_name|contains("down")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.forced_backfill \(.pgmap.pgs_by_state|map(select(.state_name|contains("forced_backfill")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.forced_recovery \(.pgmap.pgs_by_state|map(select(.state_name|contains("forced_recovery")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.incomplete \(.pgmap.pgs_by_state|map(select(.state_name|contains("incomplete")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.inconsistent \(.pgmap.pgs_by_state|map(select(.state_name|contains("inconsistent")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.peered \(.pgmap.pgs_by_state|map(select(.state_name|contains("peered")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.peering \(.pgmap.pgs_by_state|map(select(.state_name|contains("peering")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovering \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovering")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_toofull \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_toofull")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_unfound \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_unfound")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.recovery_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("recovery_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.remapped \(.pgmap.pgs_by_state|map(select(.state_name|contains("remapped")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.repair \(.pgmap.pgs_by_state|map(select(.state_name|contains("repair")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.scrubbing \(.pgmap.pgs_by_state|map(select(.state_name|contains("scrubbing")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim_error \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim_error")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.snaptrim_wait \(.pgmap.pgs_by_state|map(select(.state_name|contains("snaptrim_wait")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.stale \(.pgmap.pgs_by_state|map(select(.state_name|contains("stale")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.undersized \(.pgmap.pgs_by_state|map(select(.state_name|contains("undersized")))|reduce .[] as $state (0; . + $state.count))",
        "ceph.num_up_osds \(.osdmap.osdmap.num_up_osds)",
        "ceph.num_in_osds \(.osdmap.osdmap.num_in_osds)",
        "ceph.rdbps \(.pgmap.read_bytes_sec)",
        "ceph.wrbps \(.pgmap.write_bytes_sec)",
        "ceph.opsread \(.pgmap.read_op_per_sec)",
        "ceph.opswrite \(.pgmap.write_op_per_sec)"'|\
        awk '{
          if(NR==1){
            print
          }else{
            print "'$HOSTNAME' "$0> "'${TMPS}'"
          }
        }'
  ;;
esac

if [ -z ${HOSTNAME} ]; then
  cat ${TMPS}
elif [ -s ${TMPS} ]; then
  if [ -z ${LOG} ]; then
    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS}
  else
    zabbix_sender -c ${ZBX_CONFIG_AGENT} -i ${TMPS}  -vv >> ${LOG} 2>&1
  fi
fi

rm -f ${TMPS}
