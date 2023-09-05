# shellcheck shell=ksh

get_seqid() {
	SEQ_ID=$(<"$PLAYER/seqid")
}

incrm_seqid() {
	echo -n $((SEQ_ID + 1)) >"$PLAYER/seqid"
}

### send a raw serverbound packet
# $0 2f "$(tovarint 1)"
# # "2f" is the serverbound packet id for "swing arm" and 1 here means "left hand"
# # see the full list of packets at https://wiki.vg/Protocol
# (packet_num: hex(2), data: hex)
pkt_send() {
	# length of the to-be-compressed packet data + packet id
	len=$((${#2} / 2 + 1))
	if [ "$LZ_THRESHOLD" != "-1" ]; then

		# buggy code for packet compression
		# compression is actually optional C2S so it's safe to ignore

		# if (( $len >= $LZ_THRESHOLD )); then
		#
		# 	# data to be compressed (packet id + packet data)
		# 	pkt="$1$2"
		# 	pkt_compressed="$(echo -n "$pkt" | fromhex | tolz | tohex)"
		#
		#
		# 	# length of compressed packet, where $len is the length of the uncompressed packet
		# 	pkt_len=$(( ${#pkt_compressed} / 2 ))
		#
		# 	echo -n "$(tovarint "$pkt_len")$(tovarint "$len")$pkt_compressed" | fromhex >&3
		# else
		# compression set, but don't compress packet
		# add an extra byte to the length, we need to compensate for the "00" (compression length of 0)
		echo -n "$(tovarint "$((len + 1))")00$1$2" | fromhex >&3
		# fi
	else
		# compression isn't enabled, send as normal
		echo -n "$(tovarint "$len")$1$2" | fromhex >&3
	fi
}

HANDSHAKE_STATUS=1
HANDSHAKE_LOGIN=2
pkt_handshake() {
	pkt=$(tovarint "$VERSION")
	pkt+=$(tostring "$HOST")
	pkt+=$(toshort "$PORT")
	pkt+=$(tovarint "$1")
	pkt_send 00 "$pkt"
	STATE=$1
}

### respawn the player after a death
# pkt_hook_combat_death() {
# 	$0
# }
pkt_respawn() {
	pkt_send 07 "$(tovarint 0)"
}

### sends a message in public chat
# $0 "hello! I sent a chat message!"
# (message: string)
pkt_chat() {
	pkt=$(tostring "$1")          # message
	pkt+=$(tolong "$(timestamp)") # timestamp
	pkt+=$(tolong "$(timestamp)") # salt
	pkt+="00"                     # has signature, bool(false)
	pkt+="$(tovarint 1)"          # message count? idk what this means
	pkt+="$(repeat 11 '00')"      # "acknowleged"?? no idea what this is either but if i spam exactly 11 zeros it seems to work
	pkt_send 05 "$pkt"
}

### runs a server command
### the command response is recieved in pkt_hook_system_chat
# $0 "kill CoolElectronics"
# (command: string)
pkt_chat_command() {
	pkt=$(tostring "$1")          # message
	pkt+=$(tolong "$(timestamp)") # timestamp
	pkt+=$(tolong "$(timestamp)") # salt
	pkt+=$(tovarint 0)            # idk some crypto bullshit
	pkt+=$(tovarint 1)            # message count
	pkt+="$(repeat 11 '00')"      # "acknowleged"
	pkt_send 04 "$pkt"
}

ARM_RIGHT=0
ARM_LEFT=1
### swings the player arm
# $0 $ARM_RIGHT
# (arm: ARM_LEFT | ARM_RIGHT)
pkt_swing_arm() {
	pkt_send 2f "$(tovarint "$1")"
}

### interact with an entity
### in the standard client, this happens when right clicking something (mounting a horse, trading with a villager, etc)
# # attempt to interact with every entity in view distance
# hook_entity_move(){
# 	eid=$1
# 	$0 $eid $ARM_RIGHT 0
# }
# (eid, arm: arm_left | arm_right, sneaking: 0 | 1)
pkt_interact() {
	pkt=$(tovarint "$1")
	pkt+=$(tovarint 0) # enum for "innteract"
	pkt+=$(tovarint "$2")
	pkt+=$(tobool "$3")
	pkt_send 10 "$pkt"
}

pkt_block_interact() {
	pkt=$(tovarint "$(<"$PLAYER/eid")")
	pkt+=$(tovarint 2)
	pkt+=$1
	pkt+=$2
	pkt+=$3
	pkt+=$(tovarint 0)
	pkt+=$(tobool 0)
	pkt_send 10 "$pkt"

}

### attack an entity
# # attempt to attack every entity in view distance whenever it moves
# pkt_hook_entity_move(){
# 	eid=$1
# 	$0 $eid
# }
# (eid)
pkt_attack() {
	pkt=$(tovarint "$1")
	pkt+=$(tovarint 1) # enum for "attack"
	pkt+="00"          # "sneaking" i don't know why it needs to know this, but ok

	pkt_send 10 "$pkt"
}

FACE_BOTTOM=0
FACE_TOP=1
FACE_NORTH=2
FACE_SOUTH=3
FACE_WEST=4
FACE_EAST=5

DROP_ITEM=4
DROP_STACK=3
### drop the currently held item
# (DROP_ITEM|DROP_STACK)
pkt_drop() {
	get_seqid
	pkt=$(tovarint "$1")          # enum for "drop item"
	pkt+=$(encode_position 0 0 0) # it's always 000, idk why
	pkt+=$(tovarint $FACE_BOTTOM) # facing -Y, always

	pkt+=$(tovarint "$SEQ_ID")
	pkt_send 1d "$pkt"
	incrm_seqid
}

DIG_START=0
DIG_CANCEL=1
DIG_FINISH=2
### attempt to mine a block
# $0 $DIG_START 12 50 14
# sleep 4 # wait for enough time to mine the block
# $0 $DIG_FINISH 12 50 14
# (DIG_START | DIG_CANCEL | DIG_FINISH, x, y, z, face)
pkt_dig() {
	get_seqid
	pkt=$(tovarint $1)
	pkt+=$(encode_position "$2" "$3" "$4")
	pkt+=$(tovarint $5)
	pkt+=$(tovarint "$SEQ_ID")
	pkt_send 1d "$pkt"
	incrm_seqid
}

SNEAK=0
UNSNEAK=1
### sneak or unsneak
# (SNEAK|UNSNEAK)
pkt_sneak() {
	get_seqid
	pkt=$(tovarint "$(<"$PLAYER/eid")") # player entity id
	pkt+=$(tovarint "$1")               # enum for sneak
	pkt+=$(tovarint "$SEQ_ID")
	pkt_send 1e "$pkt"
	incrm_seqid
}

### teleport to a coordinate, within reason
# (x: decimal string, y: decimal string, z: decimal string, onground: 0 | 1)
pkt_set_position() {

	x=$(denormalize $1)
	y=$(denormalize $2)
	z=$(denormalize $3)

	pkt=$(todouble "$x")
	pkt+=$(todouble "$y")
	pkt+=$(todouble "$z")
	pkt+=$(tobool "$4")

	echo "$x" >"$PLAYER/x"
	echo "$y" >"$PLAYER/y"
	echo "$z" >"$PLAYER/z"

	pkt_send 14 "$pkt"
}

# a quick hack to fix my shitty float implementation
denormalize() {
	if (($(echo "${1#-} < 1" | bc -l))); then
		if (($(echo "$1 < 0" | bc -l))); then
			echo -n "-1"
		else
			echo -n "1"
		fi
	else
		echosafe "$1"
	fi
}

### tell server if you're grounded or not
# (0 | 1)
pkt_set_on_ground() {
	pkt_send 17 "$(tobool $1)"
}

### select an item from the hotbar
# (item: 0-8)
pkt_pick_item() {
	pkt_send 1a "$(tovarint "$1")"
}

### use item (eg, throw snowball)
pkt_use_item() {
	get_seqid
	pkt_send 32 "$(tovarint 0)$(tovarint $SEQ_ID)"
	incrm_seqid
}

pkt_use_item_on() {
	get_seqid
	pkt_send 31 "$(tovarint 0)$(encode_position 5 -60 14)$(tovarint 1)3f0000003f8000003f000000$(tobool 0)$(tovarint "$SEQ_ID")"
	pkt_swing_arm 0
	incrm_seqid
}
