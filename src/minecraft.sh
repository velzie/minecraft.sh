# shellcheck shell=bash
SRC=${BASH_SOURCE%/*}
SRC=${SRC/%minecraft.sh/.\/}
source "$SRC/types.sh"
source "$SRC/packet.sh"
source "$SRC/util.sh"
source "$SRC/hooks.sh"


# default consts
HOST=localhost
PORT=25565
TEMP=/dev/shm/minecraft.sh
USERNAME=sh
VERSION=763 # 1.20.1, the latest version at the time of making this. be warned, packet ids and format can change drastically between versions

# 0: handshaking
# 1: pinging
# 2: login
# 3: play
#
# note: do not trust this unless you know what thread you're on
STATE=0

login() {
	if ! [ -d "$TEMP" ]; then
		mkdir "$TEMP"
	fi

	# ensure we're the only one
	lsof -t lsof | xargs kill
	exec 4<>lsof

	# we need to create temporary files in memory because bash cannot send between subshells
	PLAYER_ID=$RANDOM
	PIPE="$TEMP/$PLAYER_ID.pipe"
	PLAYER="$TEMP/$USERNAME:$PLAYER_ID.mem"
	ENTITIES="$PLAYER/entities"
	LISTENER_PID="$TEMP/$PLAYER_ID.pid"
	PARENT_PID="$TEMP/$PLAYER_ID.ppid"
	mkfifo $PIPE
	mkdir -p "$PLAYER"
	mkdir -p "$ENTITIES"

	echo "ID: $PLAYER_ID"

	exec 3<>/dev/tcp/$HOST/$PORT

	STATE=0
	send_packet 00 "$(tovarint $VERSION)$(tostring $HOST)$(toshort $PORT)$(tovarint 2)"
	STATE=2
	send_packet 00 "$(tostring $USERNAME)00"

	listen <&3 &
	echo "$!" >$LISTENER_PID
	echo "$$" >$PARENT_PID

}

disconnect(){
	exec 3>&-
	exec 3<&-
	if [ ! -z "$PLAYER" ] && [ -d "$PLAYER" ]; then
		rm -r "$PLAYER"
	fi
	rm -f $PIPE
	kill $(<$LISTENER_PID)
}

listen() {

	while true; do

		# get packet length
		len=$(fromvarint)

		# motivation for using an FIFO:
		# - subshells CANNOT be used because of the need to persist state between packet frames
		# - here-strings CANNOT be used because of nul bytes (it's slower anyway probably
		# - there's no reason cmd <(subshell) wouldn't work, but it doesn't and i don't know why

		readn $len <&3 >$PIPE &
		proc_pkt <$PIPE

	done
}

proc_pkt() {
	local pkt_id=$(readhex 1)
	if [ "$pkt_id" == "" ]; then
		echo "---- disconnected from server ----"
		disconnect
		exit
	fi

	case $STATE in
	0) ;;
	1) ;;
	2)
		case $pkt_id in
		00) # disconnect
			echo "Failed to login"
			# print the disconnect reason
			cat
			return 1
			;;
		02) # login sucessful
			uuid=$(readhex 16)
			len=$(fromvarint)
			read -r "-n$len" username
			STATE=3
			pkt_hook_login "$username"
			;;
		esac
		;;
	3)
		case $pkt_id in
		1a) # disconnect
			local len=$(fromvarint)
			echo "kicked from server: $(cat)"
			;;
		23) # keepalive
			id=$(readhex 9999)
			send_packet 12 "$id"
			;;

		45) # server data
			local len=$(fromvarint)
			read -n$len motd

			echo "MOTD: $motd"
			;;
		3a) # player info (tab)
			# i'll leave this unimplemented it's annoying
			;;
		35) # player chat
			local uuid=$(readhex 16)
			local index=$(fromvarint)    # unknown what this does
			eatn 1                       # eat the signature bool
			local len=$(fromvarint)
			local message=$(readhex $len)
			local timestamp=$(readhex 8)
			local salt=$(readhex 8)      # crypto related? idk
			local unknown=$(readhex 6)   # no idea what this is

			pkt_hook_chat "$uuid" "$message" "$timestamp" "$(readhex 999999)"
			;;
		1b) # disguised chat message. not really sure when this is used?
			local len=$(fromvarint)
			local message=$(readn $len)
			len=$(fromvarint)
			local typename=$(readn $len)
			local hasname=$(readhex 1)
			len=$(fromvarint)
			local name=$(readn $len)
			echo "<system>-$message-$typename-$hasname-$name"
			;;
		38) # combat death
			local id=$(fromvarint)
			local len=$(fromvarint)

			pkt_hook_combat_death "$(readhex $len)"
			;;
		57) # set health
			local health=$(fromfloat $(readhex 4))
			local food=$(fromvarint)
			local saturation=$(fromfloat $(readhex 4))

			pkt_hook_set_health "$health" "$food" "$saturation"
			;;
		28) # login
			# get own entity-id. there are a bunch of other fields but i don't care about any of them
			# for some reason the EID is sent as a short here, everywhere else it's a varint
			echo -n $(( 0x$(readhex 4) )) >"$PLAYER/eid"
			echo -n 0 >"$PLAYER/seqid"
			;;
		2b) # update entity position
			local eid=$(fromvarint)
			# local dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# local dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# local dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			pkt_hook_entity_move $eid
			;;
		2c) # update entity position and rotation
			local eid=$(fromvarint)
			# local dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# local dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# local dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			pkt_hook_entity_move $eid
			;;
		01) # spawn entity
			local eid=$(fromvarint)

			local entity="$ENTITIES/$eid"
			mkdir -p "$entity"

			local uuid=$(readhex 16)
			local type=$(fromvarint)

			readhex 8 > "$entity/x"
			readhex 8 > "$entity/y"
			readhex 8 > "$entity/z"
		
			eatn 3 # angle stuff

			local data=$(fromvarint)

			echosafe "$uuid" > "$entity/uuid"
			echosafe "$type" > "$entity/type"
			echosafe "$data" > "$entity/data"
			
			pkt_hook_entity_spawn "$eid"
			;;
		03) # spawn player
			local eid=$(fromvarint)
			local uuid=$(readhex 16)


			local entity="$ENTITIES/$eid"
			mkdir -p "$entity"
			
			readhex 8 > "$entity/x"
			readhex 8 > "$entity/y"
			readhex 8 > "$entity/z"

			eatn 2 # angle stuff

			echosafe "$uuid" > "$entity/uuid"
			echosafe "122" > "$entity/type" # id for "player"
			>"$entity/dat"

			pkt_hook_player_spawn "$eid"
			;;
		3e) # remove entities
			local count=$(fromvarint)
			for i in $(seq $count); do
				local eid=$(fromvarint)
				pkt_hook_entity_remove "$eid"
				rm -r "$ENTITIES/$eid"
			done
			;;
		32) # ping!
			local id=$(readhex 4)
			pkt_send 20 "$id" # pong!
			;;
		*)
			pkt_hook_unknown
			;;
		esac
		;;
	esac

	# purge all remaining data to stay in sync
	cat >/dev/null
}
