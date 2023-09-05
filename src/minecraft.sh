# shellcheck shell=ksh
# shellcheck disable=SC2034

export LC_ALL=C
. src/hooks.sh
. src/types.sh
. src/packet.sh
. src/util.sh
. src/macros.sh

# default consts
HOST=${HOST:-localhost}
PORT=${PORT:-25565}
USERNAME=${USERNAME:-sh}
TEMP=/dev/shm/minecraft.sh
VERSION=763 # 1.20.1, the latest version at the time of making this. be warned, packet ids and format can change drastically between versions

# states:
# 0: handshaking
# 1: pinging
# 2: login
# 3: play


### gets the ping of a server, player count, MOTD, icon, etc
# HOST=endcrystal.me
# json=$(server_list_ping)
# echo "$json" | jq ".description.text"
# echo "players: $(echo "$json" | jq ".players.online")/$(echo "$json" | jq ".players.max")"
# echo "version: $(echo "$json" | jq ".version.name")"
# echo "ping: ${ping}ms"
# returns a JSON string
server_list_ping() {
	exec 3<>"/dev/tcp/$HOST/$PORT"

	LZ_THRESHOLD=-1
	pkt_handshake $HANDSHAKE_STATUS
	pkt_send 00

	readn "$(fromvarint <&3)" <&3 | proc_pkt

	ts=$(date +%s%N)
	{
		pkt_send 01 "$(tolong "$(date +%s)")00000000"
		readn "$(fromvarint <&3)" <&3 | proc_pkt
	} >/dev/null
	ping=$(( ( $(date +%s%N) - ts ) / 1000000 ))
}

### start the login process
### PORT is 25565 by default, HOST is localhost by default, USERNAME is sh
# HOST=tf2.mercurywork.shop
# PORT=25565
# USERNAME=juliet
# start_login
# # you must call wait_on_login before sending packets
# wait_on_login
# pkt_swing_arm $ARM_LEFT
start_login() {
	if ! [ -d "$TEMP" ]; then
		mkdir "$TEMP"
	fi

	# ensure we're the only one for debugging
	# lsof -t lsof | xargs kill
	# exec 4<>lsof

	# we need to create temporary files in memory because bash cannot send between subshells
	PLAYER_ID=$$
	PLAYER="$TEMP/$USERNAME.$PLAYER_ID"
	ENTITIES="$PLAYER/entities"
	LISTENER_PID="$TEMP/$PLAYER_ID.pid"
	PARENT_PID="$TEMP/$PLAYER_ID.ppid"
	mkdir -p "$PLAYER"
	mkdir -p "$ENTITIES"

	# spawn sigil process
	(read <> <(:)) &
	WAITPID=$!

	echo "ID: $PLAYER_ID"
	exec 3<>"/dev/tcp/$HOST/$PORT"

	LZ_THRESHOLD=-1
	echo "$LZ_THRESHOLD" >"$PLAYER/lzthreshold"
	STATE=0
	pkt_handshake $HANDSHAKE_LOGIN
	pkt_send 00 "$(tostring "$USERNAME")00"

	listen <&3 &
	echo "$!" >$LISTENER_PID
	echo "$$" >$PARENT_PID
}

### wait for login to finish
### you MUST call this at least once before sending any packets
wait_on_login() {
	wait "$WAITPID" >/dev/null
	LZ_THRESHOLD=$(<"$PLAYER/lzthreshold")
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

		if [ "$len" == "" ]; then
			pkt_hook_disconnect
			disconnect
		fi
		# create a random temporary file and immediately dump the contents of the packet into it
		#
		# under any other circumstance this would be slower, but in this case it is neccesary because it won't be buffered by anything
		# the biggest bottleneck is how fast we can readn the correct number of bytes, it does not matter what happens afterwards
		# we need to process packets as fast as physically possible, if we fall out of sync we'll eventually fail to process 0x23 Keep Alive and the server will kick us
		#
		# despite my best efforts, standard bash tends to fall behind and will inevitably get kicked. ksh20 is fast enough for our use though

		PACKET="$PLAYER/$RANDOM.dmp"
		readn "$len" <&3 >"$PACKET"

		if [ "$STATE" = "3" ]; then
			# fork(), reading the data we dumped and process it in parallel
			{
				deflate_pkt
			} &
		else
			# do not fork until the state switches to play, the penalty from having to juggle constants in files is not worth it
			deflate_pkt
		fi

	done
}

deflate_pkt() {
	if [ ! -f "$PACKET" ]; then
		echo "dropped packet of length $len"
		# pkt_hook_disconnect
		# disconnect
		return
	fi

	{
		if [ "$LZ_THRESHOLD" != "-1" ]; then
			len=$(fromvarint)
			if [ "$len" != "0" ]; then
				fromlz | proc_pkt
			else
				proc_pkt
			fi
		else
			proc_pkt
		fi
	} <"$PACKET"
	rm "$PACKET"
}

proc_pkt() {
	pkt_id=$(readhex 1)
	if [ "$pkt_id" == "" ]; then
		pkt_hook_disconnect
		disconnect
		exit
	fi

	case $STATE in
	0) # handshaking
		;;
	1) # status
		case "$pkt_id" in 
		00) # status response
			len=$(fromvarint)
			readn "$len"
			;;
		01) # ping response
			echo $(( 0x$(readhex 8) ))
			;;
		esac
		;;
	2) # login
		case $pkt_id in
		00) # disconnect
			echo "Failed to login"
			# print the disconnect reason
			cat
			return 1
			;;
		02) # login sucessful
			echo "login???"
			uuid=$(readhex 16)
			len=$(fromvarint)
			read -r "-n$len" username
			STATE=3
			pkt_hook_login "$username"
			;;
		03)
			LZ_THRESHOLD=$(fromvarint)
			echo "$LZ_THRESHOLD" >"$PLAYER/lzthreshold"
			;;
		esac
		;;
	3) # play
		case $pkt_id in
		28) # login (play)
			# this function needs to be called before it's safe to do anything else
			# get own entity-id. there are a bunch of other fields but i don't care about any of them
			# for some reason the EID is sent as a short here, everywhere else it's a varint
			echo -n $((0x$(readhex 4))) >"$PLAYER/eid"
			echo -n 0 >"$PLAYER/seqid"

			# send client information
			pkt=$(tostring "en_US") # RAHHHHH
			pkt+="01"               # our render distance. must be as small as possible to avoid timeouts
			pkt+="00"               # enable chat
			pkt+="00"               # disable chat colors
			pkt+="00"               # skin stuff
			pkt+="01"               # right hand default
			pkt+="00"               # "text filtering? what"
			pkt+="01"               # show up in tab menu
			pkt_send 08 "$pkt"

			# killing a sigil lamb is the most efficient way that i know of unblocking `wait_on_login` on the parent
			kill -9 "$WAITPID"
			;;
		1a) # disconnect
			len=$(fromvarint)
			pkt_hook_kicked "$(readhex 9999)"
			;;
		23) # keepalive
			id=$(readhex 9999)
			pkt_send 12 "$id"
			;;
		45) # server data
			len=$(fromvarint)
			read -rn"$len" motd
			# echo "MOTD: $motd"
			;;
		3a) # player info (tab)
			# i'll leave this unimplemented it's annoying
			;;
		3c) # synchronize player position
			x=$(readhex 8)
			y=$(readhex 8)
			z=$(readhex 8)
			yaw=$(readhex 4)
			pitch=$(readhex 4)
			flags=$(readhex 1)

			tid=$(fromvarint)

			x=$(fromdouble "$x")
			y=$(fromdouble "$y")
			z=$(fromdouble "$z")

			echo "$x" >"$PLAYER/x"
			echo "$y" >"$PLAYER/y"
			echo "$z" >"$PLAYER/z"

			pkt_hook_synchronize_player_position "$x" "$y" "$z" "$flags"

			# i should "confirm" the synchronization? what
			# if i don't do this, every single fucking position related packet breaks
			# i spent like 5 hours trying to figure out why i couldn't place blocks and it turned out to be because i wasn't "confirming" a completely unrelated packet
			pkt_send 00 "$(tovarint "$tid")"
			;;
		24) # chunk data and update light
			# also known as the biggest and most cursed packet
			chunkx=$((0x$(readhex 4)))
			chunky=$((0x$(readhex 4)))

			# after this is NBT data. i can't skip it and i can't know how long it is, so this is as far as i get without writing a dedicated parser.

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
			message=$(readhex "$len")
			len=$(fromvarint)
			typename=$(readhex "$len")
			hasname=$(readhex 1)
			len=$(fromvarint)
			name=$(readhex "$len")

			pkt_hook_disguised_chat "$message" "$typename" "$hasname" "$name"
			;;
		64) # system chat message
			len=$(fromvarint)
			pkt_hook_system_chat "$(readhex "$len")"
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
		2b) # update entity position
			eid=$(fromvarint)
			# dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			pkt_hook_entity_move "$eid"
			;;
		2c) # update entity position and rotation
			# eid=$(fromvarint)
			# dx=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dy=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# dz=$(( ( 0x$(readhex 2) - (128 * 256) ) / (128 * 32) ))
			# echo "$eid moved $dx $dy $dz"
			pkt_hook_entity_move "$eid"
			;;
		01) # spawn entity
			eid=$(fromvarint)

			entity="$ENTITIES/$eid"
			mkdir -p "$entity"

			uuid=$(readhex 16)
			type=$(fromvarint)

			fromdouble "$(readhex 8)" >"$entity/x"
			fromdouble "$(readhex 8)" >"$entity/y"
			fromdouble "$(readhex 8)" >"$entity/z"

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
}
