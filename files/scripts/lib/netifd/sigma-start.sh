#!/bin/sh

. /lib/wifi/platform_dependent.sh

HOSTAPD_CLI_CMD=hostapd_cli
if [ "$OS_NAME" = "UGW" ]; then
	HOSTAPD_CLI_CMD="sudo -u nwk -- $HOSTAPD_CLI_CMD"
fi

listenPort=9000
procName=$0

# clean unused process
ownPid=$$
sigmaStartPid=`ps | grep "$0" | grep -v "grep" | grep -v "$ownPid" | awk '{ print $1 }'`
kill $sigmaStartPid

killall sigma-ap.sh

if [ -z `ls $NC_COMMAND` ]; then
	NC_COMMAND=`cat /tmp/lite_nc_location`
	if [ -z `ls "$NC_COMMAND"` ]; then
		NC_COMMAND=`find / -name lite_nc | tail -n1`
		if [ -z "$NC_COMMAND" ]; then
			echo "Notice - lite_nc not found, I am using busybox"
			if [ ! -x "$BUSYBOX_BIN_PATH/busybox" ]; then
				echo "Error - busybox has no x permissions"
				exit 1
			fi
			if [ -z `"$BUSYBOX_BIN_PATH/busybox" nc 2>&1 | grep Listen` ]; then
				echo "Error - busybox nc has no listen option"
				exit 1
			fi
			NC_COMMAND="$BUSYBOX_BIN_PATH/busybox nc -l -p $listenPort"
		else
			chmod +x "$NC_COMMAND"
			echo "$NC_COMMAND" > /tmp/lite_nc_location
		fi
	else
		chmod +x "$NC_COMMAND"
	fi
else
	chmod +x "$NC_COMMAND"
fi

ncPid=`ps | grep "busybox nc -l -p $listenPort" | grep -v "grep" | awk '{ print $1 }'`
kill "$ncPid"
ncPid=`ps | grep "lite_nc" | grep -v "grep" | awk '{ print $1 }'`
kill "$ncPid"

if [ "$OS_NAME" = "RDKB" ]; then
	iptables -t mangle -D FORWARD -m state ! --state NEW -j DSCP --set-dscp 0x00
	iptables -t mangle -D FORWARD -m state --state NEW -j DSCP --set-dscp 0x14
elif [ "$OS_NAME" = "UGW" ]; then
	iptables -I zone_wan_input -p tcp --dport $listenPort -j ACCEPT
	iptables -I zone_lan_input -p tcp --dport $listenPort -j ACCEPT
fi

dirname() {
	full=$1
	file=`basename $full`
	path=${full%%$file}
	[ -z "$path" ] && path=./
	echo $path
}
thispath=`dirname $0`

cp $thispath/sigma-ap.sh /tmp/
cd /tmp
[ ! -e sigma-pipe ] && mknod sigma-pipe p

while [ `$HOSTAPD_CLI_CMD status | sed -n 's/state=//p'` != "ENABLED" ]; do echo sigma-start.sh: Waiting for interface up; sleep 3; done
while true; do $NC_COMMAND < sigma-pipe  | "./sigma-ap.sh" > ./sigma-pipe; done &
