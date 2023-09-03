# shellcheck shell=ksh
# shellcheck disable=SC2034

source src/hooks.sh
source src/types.sh
source src/packet.sh
source src/types.sh
source src/util.sh

# default consts
HOST=localhost
PORT=25565
TEMP=/dev/shm/minecraft.sh
USERNAME=sh
VERSION=763 # 1.20.1, the latest version at the time of making this. be warned, packet ids and format can change drastically between versions

# states:
# 0: handshaking
# 1: pinging
# 2: login
# 3: play

mc_login() {
	if ! [ -d "$TEMP" ]; then
		mkdir "$TEMP"
	fi

	# ensure we're the only one
	lsof -t lsof | xargs kill
	exec 4<>lsof

	# we need to create temporary files in memory because bash cannot send between subshells
	PLAYER_ID=$RANDOM
	PLAYER="$TEMP/$USERNAME:$PLAYER_ID.mem"
	ENTITIES="$PLAYER/entities"
	LISTENER_PID="$TEMP/$PLAYER_ID.pid"
	PARENT_PID="$TEMP/$PLAYER_ID.ppid"
	mkdir -p "$PLAYER"
	mkdir -p "$ENTITIES"

	echo "ID: $PLAYER_ID"

	exec 3<>/dev/tcp/$HOST/$PORT

	echo 0 >"$PLAYER/state"
	send_packet 00 "$(tovarint $VERSION)$(tostring $HOST)$(toshort $PORT)$(tovarint 2)"
	echo 3 >"$PLAYER/state"
	send_packet 00 "$(tostring $USERNAME)00"

	listen <&3 &
	echo "$!" >$LISTENER_PID
	echo "$$" >$PARENT_PID

}

disconnect() {
	exec 3>&-
	exec 3<&-
	if [ -n "$PLAYER" ] && [ -d "$PLAYER" ]; then
		rm -r "$PLAYER"
	fi
	kill "$(<"$LISTENER_PID")"
}

listen() {
	# here's the main loop! this gets run for every single packet the client processes
	while true; do

		# get packet length
		len=$(fromvarint)

		# create a random temporary file and immediately dump the contents of the packet into it
		#
		# under any other circumstance this would be slower, but in this case it is neccesary because it won't be buffered by anything
		# the biggest bottleneck is how fast we can readn the correct number of bytes, it does not matter what happens afterwards
		# we need to process packets as fast as physically possible, if we fall out of sync we'll eventually fail to process 0x23 Keep Alive and the server will kick us
		#
		# despite my best efforts, standard bash tends to fall behind and will inevitably get kicked. ksh20 is fast enough for our use though
		PACKET="$PLAYER/$RANDOM.tmp"
		readn "$len" <&3 >"$PACKET"

		# fork(), reading the data we dumped and process it in parallel
		{
			proc_pkt <"$PACKET"
			rm "$PACKET"
		} &

	done
}

proc_pkt() {
	pkt_id=$(readhex 1)
	if [ "$pkt_id" == "" ]; then
		# pkt_hook_disconnect
		# disconnect
		# exit
		echo "??"
	fi

	case "$(<"$PLAYER/state")" in
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
			echo 3 >"$PLAYER/state"
			pkt_hook_login "$username"
			;;
		esac
		;;
	3)
		case $pkt_id in
		1a) # disconnect
			len=$(fromvarint)
			pkt_hook_kicked "$(readhex 9999)"
			;;
		23) # keepalive
			id=$(readhex 9999)
			send_packet 12 "$id"
			;;

		45) # server data
			len=$(fromvarint)
			read -rn"$len" motd

			echo "MOTD: $motd"
			;;
		3a) # player info (tab)
			# i'll leave this unimplemented it's annoying
			;;
		35) # player chat
			uuid=$(readhex 16)
			index=$(fromvarint) # unknown what this does
			eatn 1              # eat the signature bool
			len=$(fromvarint)
			message=$(readhex "$len")
			timestamp=$(readhex 8)
			salt=$(readhex 8)    # crypto related? idk
			unknown=$(readhex 6) # no idea what this is

			pkt_hook_chat "$uuid" "$message" "$timestamp" "$(readhex 999999)"
			;;
		1b) # disguised chat message. not really sure when this is used?
			len=$(fromvarint)
			message=$(readn "$len")
			len=$(fromvarint)
			typename=$(readn "$len")
			hasname=$(readhex 1)
			len=$(fromvarint)
			name=$(readn "$len")
			echo "<system>-$message-$typename-$hasname-$name"
			;;
		38) # combat death
			id=$(fromvarint)
			len=$(fromvarint)

			pkt_hook_combat_death "$(readhex "$len")"
			;;
		57) # set health
			health=$(fromfloat "$(readhex 4)")
			food=$(fromvarint)
			saturation=$(fromfloat "$(readhex 4)")

			pkt_hook_set_health "$health" "$food" "$saturation"
			;;
		28) # login
			# get own entity-id. there are a bunch of other fields but i don't care about any of them
			# for some reason the EID is sent as a short here, everywhere else it's a varint
			echo -n $((0x$(readhex 4))) >"$PLAYER/eid"
			echo -n 0 >"$PLAYER/seqid"
			;;
		2b) # update entity position
			eid=$(fromvarint)
			# dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			# pkt_hook_entity_move $eid
			;;
		2c) # update entity position and rotation
			# eid=$(fromvarint)
			# dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			# pkt_hook_entity_move $eid
			;;
		01) # spawn entity
			eid=$(fromvarint)

			entity="$ENTITIES/$eid"
			mkdir -p "$entity"

			uuid=$(readhex 16)
			type=$(fromvarint)

			readhex 8 >"$entity/x"
			readhex 8 >"$entity/y"
			readhex 8 >"$entity/z"

			eatn 3 # angle stuff

			data=$(fromvarint)

			echosafe "$uuid" >"$entity/uuid"
			echosafe "$type" >"$entity/type"
			echosafe "$data" >"$entity/data"

			pkt_hook_entity_spawn "$eid"
			;;
		03) # spawn player
			eid=$(fromvarint)
			uuid=$(readhex 16)

			entity="$ENTITIES/$eid"
			mkdir -p "$entity"

			readhex 8 >"$entity/x"
			readhex 8 >"$entity/y"
			readhex 8 >"$entity/z"

			eatn 2 # angle stuff

			echosafe "$uuid" >"$entity/uuid"
			echosafe "122" >"$entity/type" # id for "player"
			: >"$entity/dat"

			pkt_hook_player_spawn "$eid"
			;;
		3e) # remove entities
			count=$(fromvarint)
			for _i in $(seq "$count"); do
				eid=$(fromvarint)
				pkt_hook_entity_remove "$eid"
				rm -r "${ENTITIES:?}/$eid"
			done
			;;
		32) # ping!
			id=$(readhex 4)
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
