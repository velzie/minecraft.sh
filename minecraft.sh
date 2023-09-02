# shellcheck shell=bash
. ./types.sh

# consts
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


hexpacket_len() {
	tovarint $((($(echo -n "$1" | fromhex | wc -c) + 1)))
}

# (packet_num: hex(2), data: hex(unsized))
send_packet() {
	echo -n "$(hexpacket_len "$2")$1$2" | fromhex >&3
}
# (bytes:int) -> hex string
readhex() {
	head -c $1 | tohex
}

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
	mkfifo $PIPE
	mkdir -p "$PLAYER"

	exec 3<>/dev/tcp/$HOST/$PORT

	STATE=0
	send_packet 00 "$(tovarint $VERSION)$(tostring $HOST)$(toshort $PORT)$(tovarint 2)"
	STATE=2
	send_packet 00 "$(tostring $USERNAME)00"

	listen <&3 &
	LISTENER_PID=$!

}


cleanup(){
	kill $LISTENER_PID
	exec 3>&-
	exec 3<&-
	if [ ! -z "$PLAYER" ] && [ -d "$PLAYER" ]; then
		rm -rf "$PLAYER"
	fi
	rm -f $PIPE
}

listen() {

	while true; do

		# get packet length
		len=$(fromvarint)

		# motivation for using an FIFO:
		# - subshells CANNOT be used because of the need to persist state between packet frames
		# - here-strings CANNOT be used because of nul bytes (it's slower anyway probably
		# - temporary files are too slow, we need to respond to keepalives as soon as possible to avoid a kick
		# - there's no reason cmd <(subshell) wouldn't work, but it doesn't and i don't know why

		head -c $len <&3 >$PIPE &
		proc_pkt <$PIPE

	done
}

proc_pkt() {
	local pkt_id=$(readhex 1)
	if [ "$pkt_id" == "" ]; then
		echo "---- disconnected from server ----"
		cleanup
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
			echo "logged in as $username"
			STATE=3
			pkt_respawn
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
			local motd=$(head -c$len)

			echo "MOTD: $motd"
			;;
		3a) # player info (tab)
			# i'll leave this unimplemented it's annoying
			;;
		35) # player chat
			local uuid=$(readhex 16)
			local index=$(fromvarint) # unknown what this does
			head -c1 >/dev/null      # eat the signature bool
			local len=$(fromvarint)
			local message=$(head -c$len)
			local timestamp=$(readhex 8)
			local salt=$(readhex 8)    # crypto related? idk
			local unknown=$(readhex 6) # no idea what this is

			local username=$(jq -r ".insertion") # i don't technically *need* jq but it's easy

			echo "<$username> $message"
			;;
		1b) # disguised chat message. not really sure when this is used?
			local len=$(fromvarint)
			local message=$(head -c$len)
			len=$(fromvarint)
			local typename=$(head -c$len)
			local hasname=$(readhex 1)
			len=$(fromvarint)
			local name=$(head -c$len)
			echo "<system>-$message-$typename-$hasname-$name"
			;;
		38) # combat death
			local id=$(fromvarint)
			local len=$(fromvarint)
			local reason=$(jq -r ".translate")
			echo "died! $reason"
			pkt_respawn
			;;
		57) # set health
			local health=$(fromfloat $(readhex 4))
			local food=$(fromvarint)
			local saturation=$(fromfloat $(readhex 4))
			echo "health: $health, food: $food, saturation: $saturation"
			;;
		28) # login
			# get own entity-id. there are a bunch of other fields but i don't care about any of them
			echo -n $(( 0x$(readhex 4) )) >"$PLAYER/eid"
			echo -n 0 >"$PLAYER/seqid"
			;;
		*)
			# echo "unknown packet $pkt_id"
			;;
		esac
		;;
	esac

	# purge all remaining data to stay in sync
	cat >/dev/null
}

pkt_respawn() {
	send_packet 07 "$(tovarint 0)"
}

pkt_chat() {
	local pkt=$(tostring $1)   # message
	pkt+=$(tolong $(date +%s)) # timestamp
	pkt+=$(tolong $(date +%s)) # salt
	pkt+="00"                  # has signature, bool(false)
	pkt+="$(tovarint 1)"       # message count? idk what this means
	pkt+="$(repeat 11 '00')"   # "acknowleged"?? no idea what this is either but if i spam exactly 11 zeros it seems to work
	send_packet 05 "$pkt"
}
pkt_chat_command() {
	local pkt=$(tostring "$1")   # message
	pkt+=$(tolong $(date +%s)) # timestamp
	pkt+=$(tolong $(date +%s)) # salt
	pkt+=$(tovarint 0)         # idk some crypto bullshit
	pkt+=$(tovarint 1)         # message count
	pkt+="$(repeat 11 '00')"   # "acknowleged"
	send_packet 04 "$pkt"
}

get_seqid(){
	SEQ_ID=$(<$PLAYER/seqid)
}
incrm_seqid(){
	echo -n $(( SEQ_ID + 1))>"$PLAYER/seqid"
}

# (arm: 0 | 1)
pkt_swing_arm(){
	send_packet 2f $(tovarint $1)
}
pkt_drop_item(){
	get_seqid
	send_packet 1d "$(tovarint 4)$(encode_position 0 0 0)$(tovarint 0)$(tovarint $SEQ_ID)"
	incrm_seqid
}
pkt_drop_stack(){
	get_seqid
	send_packet 1d "$(tovarint 3)$(encode_position 0 0 0)$(tovarint 0)$(tovarint $SEQ_ID)"
	incrm_seqid
}
pkt_sneak(){
	get_seqid
	send_packet 1e "$(tovarint $(<$PLAYER/eid))$(tovarint 0)$(tovarint $SEQ_ID)"
	incrm_seqid
}
pkt_unsneak(){
	get_seqid
	send_packet 1e "$(tovarint $(<$PLAYER/eid))$(tovarint 1)$(tovarint $SEQ_ID)"
	incrm_seqid
}
