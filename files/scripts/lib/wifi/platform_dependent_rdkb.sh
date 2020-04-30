#!/bin/sh

export OS_NAME="RDKB"
export BINDIR="/usr/sbin"
export SCRIPTS_PATH="/etc/wave/scripts"
export ETC_CONFIG_WIRELESS_PATH="/nvram/etc/config/wireless"
export DEFAULT_DB_PATH="/etc/wave/db"
export RADIO_MAP_FILE="/etc/wave/db/radio_map_file"
export UCI_DB_PATH="/nvram/etc/config"
export BUSYBOX_BIN_PATH="/nvram"
export NC_COMMAND="/lib/netifd/lite_nc"
export WAVE_COMPONENTS_PATH="/etc/wave/bins"
export CAL_FILES_PATH="/nvram/etc/wave_calibration"

## for wlan debug collect
export WLAN_LOG_FILE_NAME=wlanLog
export SYSLOG_CONF=/etc/syslog-ng/syslog-ng.conf
export DEBUG_SYSLOG_CONF=/nvram/syslog-ng-debug.conf
export DUMP_HEADER_MAGIC="INTL"
export TMP_PATH=/tmp
export MY_NAME_DebugLog="logs_dump"
export TMP_LOGS_PATH=${TMP_PATH}/debug_logs
export WLAN_LOG_FILE_PATH=/var/log/${WLAN_LOG_FILE_NAME}
export WAVE600_FW_DUMP_FILE_PREFIX="/proc/net/mtlk/card"
export WAVE600_FW_DUMP_FILE_SUFFIX="/FW/fw_dump"
export WAVE500_FW_DUMP_FILE_PREFIX="/proc/net/mtlk/wlan"
export WAVE500_FW_DUMP_FILE_SUFFIX="/fw_dump"
export FW_DUMP_OUT_PATH=${TMP_LOGS_PATH}/fw_tmp_dump
export DUMP_IN_PATH=/tmp/fw_tmp_dump

export DB_LOC=/nvram/etc
export FW_DUMP_LOC=${DB_LOC}
export DB_LOC_NAME=config
export CONF_LOC=/var/run
export NVRAM_LOGS_LOC=/nvram/logs
export VAR_LOGS_LOC=/var/log

export DUMP_UTIL=dump_handler
export JOURNALCTRL_UTIL=/bin/journalctl

export LTQ_CODE_WAVE500="1bef:08"
export LTQ_CODE_WAVE600="8086:09"
export WAVE_COMPONENTS_FILE="/etc/wave/bins/wave_components.ver"

## logs for debug
export module1="HALWLAN"
export module1_LogFile="/var/log/user"
export module2="mtlk"
export module2_LogFile="/var/log/user"
export module3="hostapd"
export module3_LogFile="/var/log/daemon"
export module4="DWPAL"
export module4_LogFile="/var/log/user"

export IN_FILES=$(echo "$module1_LogFile $module2_LogFile $module3_LogFile $module4_LogFile" | xargs -n1 | sort -u | xargs)
export MATCHES="$module1\|$module2\|$module3\|$module4"
