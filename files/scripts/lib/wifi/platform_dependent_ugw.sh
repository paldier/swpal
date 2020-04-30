#!/bin/sh

export OS_NAME="UGW"
export BINDIR="/opt/intel/bin"
export SCRIPTS_PATH="/opt/intel/wave/scripts"
export ETC_CONFIG_WIRELESS_PATH="/etc/config/wireless"
export DEV_CREAT_PATH="/dev"
export DEFAULT_DB_PATH="/opt/intel/wave/db"
export UCI_DB_PATH="/etc/config"
export BUSYBOX_BIN_PATH="/bin"
export NC_COMMAND="/bin/lite_nc"
export WAVE_COMPONENTS_PATH="/etc"
export CAL_FILES_PATH="/tmp/wlanconfig"

## for wlan debug collect
export WLAN_LOG_FILE_NAME=wlanLog
export SYSLOG_CONF=""
export DEBUG_SYSLOG_CONF=""
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

export FW_DUMP_LOC=/opt/intel/wave
export DB_LOC=/etc
export DB_LOC_NAME=config
export CONF_LOC=/var/run
export NVRAM_LOGS_LOC=""
export VAR_LOGS_LOC=/var/log

export DUMP_UTIL=/opt/intel/bin/dump_handler
export JOURNALCTRL_UTIL=""
export SYSLOG_NG_UTIL=""

export LTQ_CODE_WAVE500="1bef:08"
export LTQ_CODE_WAVE600="8086:09"
export WAVE_COMPONENTS_FILE="/etc/wave_components.ver"

## logs for debug
export module1=""
export module1_LogFile=""
export module2=""
export module2_LogFile=""
export module3="hostapd"
export module3_LogFile="/var/log/messages"
export module4=""
export module4_LogFile=""

export IN_FILES=$(echo "$module1_LogFile $module2_LogFile $module3_LogFile $module4_LogFile" | xargs -n1 | sort -u | xargs)
export MATCHES="$module1\|$module2\|$module3\|$module4"
