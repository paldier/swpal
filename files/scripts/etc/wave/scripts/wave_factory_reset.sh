#!/bin/sh

. /lib/wifi/platform_dependent.sh

#
# This script performs wifi factory reet
#
# perform full factory - wave_factory_reset.sh
# perform factory for vap wlan0.0 - wave_factory_reset.sh vap wlan0.0
# perform factory for radio wlan0 - wave_factory_reset.sh radio wlan0
# use alternate db files for the factory - wave_factory_reset.sh -p <alternate directory name>
# perform factory reset and create user defined number of vaps - wave_factory_reset.sh -v <number of vaps per radio>
# perform factory and choose which radio is set to which PCI slot - In the general database folder create configuration file name radio_map_file
#         map file example: radio0 PCI_SLOT01
#                           radio2 PCI_SLOT02
#

UCI=`which uci`

# Process optional arguments -p and/or -v
while getopts "p:v:" OPTS; do
        if [ "$OPTS" = "p" ]; then
                if [ "${OPTARG//[0-9A-Za-z_-]/}" = "" ]; then
                        if [ -d $DEFAULT_DB_PATH/"$OPTARG" ]; then
                                echo "config wlan-factory 'config'" > $UCI_DB_PATH/factory_mode
                                echo "        option mode '"$OPTARG"'" >> $UCI_DB_PATH/factory_mode
                                SET_FACTORY_MODE=1
                        else
                                echo "requested default DB folder "$OPTARG" does not exist" > /dev/console
                        fi
                else
                        echo "illegal default DB folder requested "$OPTARG". must use only \"0-9,a-z,A-Z,_,-\"" > /dev/console
                fi
        elif [ "$OPTS" = "v" ]; then
                if [ "${OPTARG//[0-9]/}" = "" ] && [ "$OPTARG" -le 8 ]
                then
                        vapCount="$OPTARG"
                        echo "requested factory reset in "$vapCount"+"$vapCount" mode" > /dev/console
                else
                        echo "illegal default number of VAPs requested "$OPTARG". must use only \"0-8\"" > /dev/console
                fi
        fi
done

if [ -f $UCI_DB_PATH/factory_mode ]; then
	FACTORY_MODE=`cat $UCI_DB_PATH/factory_mode | grep "option mode" | awk -F "'" '{print $2}'`
	DEFAULT_DB_PATH=$DEFAULT_DB_PATH/$FACTORY_MODE
fi
echo "factory reset using default files from $DEFAULT_DB_PATH" > /dev/console

DEFAULT_DB_STATION_VAP=$DEFAULT_DB_PATH/wireless_def_station_vap
DEFAULT_DB_RADIO_5=$DEFAULT_DB_PATH/wireless_def_radio_5g
DEFAULT_DB_RADIO_24=$DEFAULT_DB_PATH/wireless_def_radio_24g
DEFAULT_DB_VAP=$DEFAULT_DB_PATH/wireless_def_vap_db
DEFAULT_DB_VAP_SPECIFIC=$DEFAULT_DB_PATH/wireless_def_vap_
TMP_CONF_FILE=$(mktemp /tmp/tmpConfFile.XXXXXX)

DUMMY_VAP_OFSET=100

. $DEFAULT_DB_PATH/defaultNumOfVaps

function usage(){
	echo "usage: $0 [vap|radio|all_radios] <interface name>" > /dev/console
}

# Check the MAC address of the interface.
function check_mac_address(){
	local board_mac_check ret_val

	board_mac_check=$1

	ret_val=1

	board_mac_check=${board_mac_check//:/""}
	if [ "${board_mac_check//[0-9A-Fa-f]/}" != "" ]; then
		echo "$0: wrong MAC Address format!" > /dev/console
		ret_val=0
	fi

	echo $ret_val
}

# Calculate and update the MAC address of the interface.
update_mac_address()
{

	# Define local parameters
	local interface_name radio_name radio_index vap_index phy_offset board_mac mac_address \
	board_mac1 board_mac23 board_mac46 vap_mac4 vap_mac5 vap_mac6

	interface_name=$1
	sta_flag=$2

	#for station use master interface (for example for wlan1 radio_name should be wlan0).
	radio_name=${interface_name%%.*}
	[ "$radio_name" = "wlan0" ] && phy_offset=16
	[ "$radio_name" = "wlan2" ] && phy_offset=33
	[ "$radio_name" = "wlan4" ] && phy_offset=50

	if [ "$radio_name" == "$interface_name" ] ; then
		if [ "$sta_flag" == "sta" ] ; then
			vap_index=1
		else
			# master VAP
			vap_index=0
		fi
	else
		# slave VAPs
		vap_index=${interface_name##*.}
		vap_index=$((vap_index+2))
	fi

	rdk_error=0
	if [ "$OS_NAME" = "RDKB" ]; then
		mac_address=`itstore_mac_db $((${radio_name##wlan}/2)) ${vap_index}`
		if [ "$(check_mac_address $mac_address)" != "1" ]; then
			echo "$0: ERROR: Retrival of default MAC Address from ITstore Failed !" > /dev/console
			echo "$0: Check the ITstore Production settings and get the correct Mac address" > /dev/console
			rdk_error=1
		fi
	fi

	if [ "$OS_NAME" = "UGW" -o "$rdk_error" = "1" ]; then
		if [ -e "/nvram/etc/wave/wav_base_mac" ]; then
			source /nvram/etc/wave/wav_base_mac
			board_mac=${board_mac##*HWaddr }
			board_mac=${board_mac%% *}
		elif [ "$rdk_error" = "1" ]; then
			board_mac="00:50:F1:80:00:00"
		else
			board_mac=`ifconfig eth0_1`
			board_mac=${board_mac##*HWaddr }
			board_mac=${board_mac%% *}
		fi

		if [ "$board_mac" == "00:50:F1:64:D7:FE" ] || [ "$board_mac" == "00:50:F1:80:00:00" ]
		then
			echo "$0:  USING DEAFULT MAC, MAC should be different than 00:50:F1:64:D7:FE and 00:50:F1:80:00:00 ##" > /dev/console
		fi

		# Divide the board MAC address to the first 3 bytes and the last 3 byte (which we are going to increment).
		board_mac1=0x`echo $board_mac | cut -c 1-2`
		board_mac23=`echo $board_mac | cut -c 4-8`
		board_mac46=0x`echo $board_mac | sed s/://g | cut -c 7-12`

		# Increment the last byte by the the proper incrementation according to the physical interface (wlan0/wlan2/wlan4)
		board_mac46=$((board_mac46+phy_offset))

		# For STA, use MAC of physical AP incremented by 1 (wlan1 increment wlan0 by 1).
		# For VAP, use MAC of physical AP incremented by the index of the interface name + 2 (wlan0.0 increment wlan0 by 2, wlan2.2 increment wlan2 by 2).
		board_mac46=$((board_mac46+$vap_index))

		# Generate the new MAC.
		vap_mac4=$((board_mac46/65536))
		board_mac46=$((board_mac46-vap_mac4*65536))
		vap_mac5=$((board_mac46/256))
		board_mac46=$((board_mac46-vap_mac5*256))
		vap_mac6=$board_mac46
		# If the 4th byte is greater than FF (255) set it to 00.
		[ $vap_mac4 -ge 256 ] && vap_mac4=0

		mac_address=`printf '%02X:%s:%02X:%02X:%02X' $board_mac1 $board_mac23 $vap_mac4 $vap_mac5 $vap_mac6`
	fi
	echo "$mac_address"
}

function set_conf_to_file(){
	rpc_idx=$1
	specific_conf_file=$2
	template_conf_file=$3
	output_conf_file=$4

	if [ -f $specific_conf_file ]; then
		local tmp_conf_file=$(mktemp /tmp/Local_tmp_conf_file.XXXXXX)
		cat $template_conf_file | sed "s,option ssid '[^']*,&_$rpc_idx,g" > $tmp_conf_file

		arr=`cat $specific_conf_file | grep "option" | awk '{ print $2 }' | uniq`
		for item in $arr
		do
			sed -i "/$item/d" $tmp_conf_file
		done

		cat $specific_conf_file >> $tmp_conf_file
		cat $tmp_conf_file >> $output_conf_file
		rm $tmp_conf_file
	else
		# save all the rest of the defaults + add suffix to ssid
		cat $template_conf_file | sed "s,option ssid '[^']*,&_$rpc_idx,g" >> $output_conf_file
	fi
}

function create_station(){
	local rpc_idx=$1
	local sta_idx=$((rpc_idx+1))
	local vap_idx=$((10+sta_idx*16))

	if [ -f $DEFAULT_DB_STATION_VAP ]; then
		echo "config wifi-iface 'default_radio$vap_idx'" >> $tmp_wireless
		echo "		option device 'radio$rpc_idx'" >> $tmp_wireless
		echo "		option ifname 'wlan$sta_idx'" >> $tmp_wireless
		local mac=`update_mac_address wlan$rpc_idx sta`
		echo "		option macaddr '$mac'" >> $tmp_wireless
		cat $DEFAULT_DB_STATION_VAP >> $tmp_wireless
	fi
}

radio_map_file_content=
get_index_from_map_file_return_value=
function get_index_from_map_file(){
	local phy_name=$1

	local pciIndex=$(grep PCI_SLOT_NAME /sys/class/ieee80211/${phy_name}/device/uevent | awk -F":" '{print $2}')
	local map_line=$(echo "$radio_map_file_content" | grep -nm1 PCI_SLOT${pciIndex})
	local radio_name=$(echo "$map_line" | awk '{print $1}' | awk -F":" '{print $2}')
	local line_number=$(echo "$map_line" | awk '{print $1}' | awk -F":" '{print $1}')

	# delete the used line
	radio_map_file_content=$(echo "$radio_map_file_content" | sed "${line_number}d")

	get_index_from_map_file_return_value=${radio_name//[a-z]/}
}

function validate_radio_map_file(){
	if [ ! -f "$RADIO_MAP_FILE" ]; then
		# no map file supplied
		return
	fi

	radio_map_file_content=$(cat $RADIO_MAP_FILE)
	local radio_index
	local phys=`ls /sys/class/ieee80211/`
	for phy in $phys; do
		get_index_from_map_file $phy
		radio_index=$get_index_from_map_file_return_value
		if [ -z $radio_index ]; then
			echo "RADIO_MAP_FILE is invalid. not using it" > /dev/console
			radio_map_file_content=
			return
		fi
	done

	echo "using radio map configuration file" > /dev/console
	radio_map_file_content=$(cat $RADIO_MAP_FILE)
}

function full_reset(){

	echo "$0: Performing full factory reset..." > /dev/console

	if [ X$vapCount == "X" ]; then
		echo "using default number of VAPs" > /dev/console
	else
		DEFAULT_NO_OF_VAPS="$vapCount"
		echo "overriding default number of VAPs" > /dev/console
	fi

	if [ ! -d $UCI_DB_PATH ]; then
		mkdir -p $UCI_DB_PATH
	fi

	# network file is required by UCI
	if [ ! -f $UCI_DB_PATH/network ]; then
		touch $UCI_DB_PATH/network
	fi

	# clean uci cache
	uci revert wireless > /dev/null 2>&1
	uci revert meta-wireless > /dev/null 2>&1

	# Setup default wireless UCI DB

	cat /dev/null > $UCI_DB_PATH/wireless
	rm $UCI_DB_PATH/meta-wireless > /dev/null 2>&1
	rm /tmp/meta-wireless > /dev/null 2>&1
	phys=`ls /sys/class/ieee80211/`
	iface_idx=0

	local tmp_wireless=$(mktemp /tmp/wireless.XXXXXX)
	local tmp_meta=$(mktemp /tmp/meta-wireless.XXXXXX)

	validate_radio_map_file

	# Fill Radio interfaces
	for phy in $phys; do
		if [ -n "$radio_map_file_content" ]; then
			get_index_from_map_file $phy
			iface_idx=$get_index_from_map_file_return_value
		fi

		iface="wlan$iface_idx"
		new_mac=`update_mac_address $iface`
		`iw $phy info | grep "* 5... MHz" > /dev/null`
		is_radio_5g=$?
		echo "config wifi-device 'radio$iface_idx'" >> $tmp_wireless
		echo "        option phy '$phy'"	>> $tmp_wireless
		echo "        option macaddr '$new_mac'" >> $tmp_wireless

		# the radio configuration files must be named in one of the following formats:
		# <file name>
		# <file name>_<iface idx>
		# <file name>_<iface idx>_<HW type>_<HW revision>
		board=`iw dev $iface iwlwav gEEPROM | grep "HW type\|HW revision" | awk '{print $4}' | tr '\n' '_' | sed "s/.$//"`
		if [ $is_radio_5g = '0' ]; then
			set_conf_to_file $iface_idx ${DEFAULT_DB_RADIO_5}_${iface_idx} $DEFAULT_DB_RADIO_5  $TMP_CONF_FILE
			set_conf_to_file $iface_idx ${DEFAULT_DB_RADIO_5}_${iface_idx}_${board} $TMP_CONF_FILE $tmp_wireless

			local dummy_value=`cat $DEFAULT_DB_RADIO_5 | grep sDisableMasterVap | awk '{ print $3 }'`
		else
			set_conf_to_file $iface_idx ${DEFAULT_DB_RADIO_24}_${iface_idx} $DEFAULT_DB_RADIO_24  $TMP_CONF_FILE
			set_conf_to_file $iface_idx ${DEFAULT_DB_RADIO_24}_${iface_idx}_${board} $TMP_CONF_FILE $tmp_wireless

			local dummy_value=`cat $DEFAULT_DB_RADIO_24 | grep sDisableMasterVap | awk '{ print $3 }'`
		fi
		local dummy_defined=$?
		rm -f $TMP_CONF_FILE

		# Add per-radio meta-data
		echo "config wifi-device 'radio$iface_idx'" >> $tmp_meta
		echo "        option param_changed '1'" >> $tmp_meta
		echo "        option interface_changed '0'" >> $tmp_meta

		if [[ $dummy_defined -eq 0 && "$dummy_value" == "'1'" ]]
		then
			# Add dummy VAP
			dummy_idx=$((DUMMY_VAP_OFSET+iface_idx))
			echo "config wifi-iface 'default_radio$dummy_idx'" >> $tmp_wireless
			echo "        option device 'radio$iface_idx'" >> $tmp_wireless
			echo "        option ifname 'wlan$iface_idx'" >> $tmp_wireless

			# Add dummy VAP meta-data
			echo "config wifi-iface 'default_radio$dummy_idx'" >> $tmp_meta
			echo "        option device 'radio$iface_idx'" >> $tmp_meta
			echo "        option param_changed '0'" >> $tmp_meta

			new_mac=`update_mac_address wlan$iface_idx`
			echo "        option macaddr '$new_mac'" >> $tmp_wireless

			echo "        option network 'lan'" >> $tmp_wireless
			echo "        option mode 'ap'" >> $tmp_wireless
			echo "        option hidden '1'" >> $tmp_wireless
			echo "        option ssid 'dummy_ssid_$iface_idx'" >> $tmp_wireless
		fi
		
		# Fill VAP interfaces
		vap_idx=0
		while [ $vap_idx -lt $DEFAULT_NO_OF_VAPS ]; do
			rpc_idx=$((10+iface_idx*16+vap_idx))

			echo "config wifi-iface 'default_radio$rpc_idx'" >> $tmp_wireless
			echo "        option device 'radio$iface_idx'" >> $tmp_wireless
			minor=".$vap_idx"
			
			echo "        option ifname 'wlan$iface_idx$minor'" >> $tmp_wireless
			new_mac=`update_mac_address wlan$iface_idx$minor`
			echo "        option macaddr '$new_mac'" >> $tmp_wireless

			set_conf_to_file $rpc_idx $DEFAULT_DB_VAP_SPECIFIC$rpc_idx $DEFAULT_DB_VAP  $tmp_wireless

			# Add per-vap meta-data
			echo "config wifi-iface 'default_radio$rpc_idx'" >> $tmp_meta
			echo "        option device 'radio$iface_idx'" >> $tmp_meta
			echo "        option param_changed '0'" >> $tmp_meta

			vap_idx=$((vap_idx+1))

		done
		create_station "$iface_idx"

		iface_idx=$((iface_idx+2))
	done


	mv $tmp_wireless $UCI_DB_PATH/wireless
	mv $tmp_meta /tmp/meta-wireless
	ln -s /tmp/meta-wireless $UCI_DB_PATH/meta-wireless

	echo "$0: Done..." > /dev/console

}

function reset_radio(){

	echo "$0: Performing radio reset for radio $1..." > /dev/console
	iface_name=$1
	radio_idx=`echo $iface_name | sed "s/[^0-9]//g"`
	phy_idx=`iw $iface_name info | grep wiphy | awk '{ print $2 }'`

	# remove all configurable parameters, since there might be parameters which do not exist in the default db file.
	extra_params=`$UCI show wireless.radio$radio_idx | grep "wireless.radio$radio_idx\." | grep -v "\.phy" \
	| grep -v "\.type" | grep -v "\.macaddr" | awk -F"=" '{ print $1 }'`

	for option in $extra_params
	do
		$UCI delete $option
	done
	
	`iw phy$phy_idx info | grep "* 5... MHz" > /dev/null`
	is_radio_5g=$?

	# the radio configuration files must be named in one of the following formats:
	# <file name>
	# <file name>_<radio idx>
	# <file name>_<radio idx>_<HW type>_<HW revision>
	board=`iw dev $iface_name iwlwav gEEPROM | grep "HW type\|HW revision" | awk '{print $4}' | tr '\n' '_' | sed "s/.$//"`
	if [ $is_radio_5g = '0' ]; then
		set_conf_to_file $radio_idx ${DEFAULT_DB_RADIO_5}_${radio_idx} $DEFAULT_DB_RADIO_5  ${TMP_CONF_FILE}_
		set_conf_to_file $radio_idx ${DEFAULT_DB_RADIO_5}_${radio_idx}_${board} ${TMP_CONF_FILE}_ $TMP_CONF_FILE
	else
		set_conf_to_file $radio_idx ${DEFAULT_DB_RADIO_24}_${radio_idx} $DEFAULT_DB_RADIO_24  ${TMP_CONF_FILE}_
		set_conf_to_file $radio_idx ${DEFAULT_DB_RADIO_24}_${radio_idx}_${board} ${TMP_CONF_FILE}_ $TMP_CONF_FILE
	fi
	rm ${TMP_CONF_FILE}_
	db_file=$TMP_CONF_FILE

	#set default params from template file
	while read line
	do
		param=`echo $line | awk '{ print $2 }'`
		# read value from default db. remove extra \ and '
		value=`echo $line | sed "s/[ ]*option $param //g" |  sed "s/[\\']//g"`
		
		$UCI set wireless.radio$radio_idx.$param="$value"
		res=`echo $?`
		if [ $res -ne '0' ]; then
			echo "$0: Error setting $param..." > /dev/console
		fi
	done < $db_file
	rm -f $TMP_CONF_FILE

	$UCI set meta-wireless.radio${radio_idx}.param_changed=1

	echo "$0: Done..." > /dev/console
}

function reset_vap(){

	echo "$0: Performing Vap reset for VAP $1 ..." > /dev/console

	def_radio=`$UCI show | grep ifname=\'$1\' | awk -F"." '{ print $2 }'`
	if [ X$def_radio == "X" ]; then
		echo "$0: Error, can't find VPA in UCI DB" > /dev/console
		if [ $SET_FACTORY_MOD -eq 1 ]; then
			rm $UCI_DB_PATH/factory_mode
		fi
		exit 1
	fi
	
	glob_vap_idx=`echo $def_radio | sed "s/[^0-9]*//"`

	# remove all configurable parameters, since there might be parameters which do not exist in the default db file.
	extra_params=`$UCI show wireless.$def_radio | grep "wireless.$def_radio\." | grep -v "\.device" \
	| grep -v "\.ifname" |  grep -v "\.macaddr" | awk -F"=" '{ print $1 }'`

	for option in $extra_params
	do
		$UCI delete $option
	done

	set_conf_to_file $glob_vap_idx $DEFAULT_DB_VAP_SPECIFIC$glob_vap_idx $DEFAULT_DB_VAP  $TMP_CONF_FILE

	#set default params from template file
	while read line
	do
		param=`echo $line | awk '{ print $2 }'`
		# read value from default db and add _<index> to SSID. remove extra \ and '
		value=`echo $line | sed "s/[ ]*option $param //g" |  sed "s/[\\']//g"`
		
		$UCI set wireless.$def_radio.$param="$value"
		res=`echo $?`
		if [ $res -ne '0' ]; then
			echo "$0: Error setting $param..." > /dev/console
		fi
	done < $TMP_CONF_FILE
	rm $TMP_CONF_FILE

	$UCI set meta-wireless.${def_radio}.param_changed=1

	echo "$0: Done..." > /dev/console

}


case $1 in
	radio)
		if [ "$#" -ne 2 ]; then
			usage
			if [ $SET_FACTORY_MODE -eq 1 ]; then
				rm $UCI_DB_PATH/factory_mode
			fi
			exit 1
		fi
		reset_radio $2
		break
		;;
	all_radios)
		radios=`ifconfig -a | grep "wlan[0|2|4] " | awk '{ print $1 }'`
		for iface in $radios; do
			reset_radio $iface
		done
		break
		;;
	vap)
		if [ "$#" -ne 2 ]; then
			usage
			if [ $SET_FACTORY_MODE -eq 1 ]; then
				rm $UCI_DB_PATH/factory_mode
			fi
			exit 1
		fi
		reset_vap $2
		break
		;;
	*)
		full_reset
		;;
esac

