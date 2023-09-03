# shellcheck shell=bash


hexpacket_len() {
	# [todo] use expr or {#} instead
	tovarint $((($(echo -n "$1" | fromhex | wc -c) + 1)))
}

get_seqid(){
	SEQ_ID=$(<$PLAYER/seqid)
}

incrm_seqid(){
	echo -n $(( SEQ_ID + 1))>"$PLAYER/seqid"
}

### send a raw serverbound packet
# $0 2f "$(tovarint 1)"
# # "2f" is the serverbound packet id for "swing arm" and 1 here means "left hand"
# # see the full list of packets at https://wiki.vg/Protocol
# (packet_num: hex(2), data: hex)
send_packet() {
	echo -n "$(hexpacket_len "$2")$1$2" | fromhex >&3
}

### respawn the player after a death
# pkt_hook_combat_death() {
# 	$0
# }
pkt_respawn() {
	send_packet 07 "$(tovarint 0)"
}

### sends a message in public chat
# $0 "hello! I sent a chat message!"
# (message: string)
pkt_chat() {
	pkt=$(tostring "$1")   # message
	pkt+=$(tolong $(date +%s)) # timestamp
	pkt+=$(tolong $(date +%s)) # salt
	pkt+="00"                  # has signature, bool(false)
	pkt+="$(tovarint 1)"       # message count? idk what this means
	pkt+="$(repeat 11 '00')"   # "acknowleged"?? no idea what this is either but if i spam exactly 11 zeros it seems to work
	send_packet 05 "$pkt"
}

### runs a server command
### note: there is currently no way to recieve the feedback after the command
# $0 "kill CoolElectronics"
# (command: string)
pkt_chat_command() {
	pkt=$(tostring "$1") # message
	pkt+=$(tolong $(date +%s)) # timestamp
	pkt+=$(tolong $(date +%s)) # salt
	pkt+=$(tovarint 0)         # idk some crypto bullshit
	pkt+=$(tovarint 1)         # message count
	pkt+="$(repeat 11 '00')"   # "acknowleged"
	send_packet 04 "$pkt"
}

ARM_RIGHT=0
ARM_LEFT=1
### swings the player arm
# $0 $ARM_RIGHT
# (arm: ARM_LEFT | ARM_RIGHT)
pkt_swing_arm(){
	send_packet 2f $(tovarint $1)
}

### interact with an entity
### in the standard client, this happens when right clicking something (mounting a horse, trading with a villager, etc)
# # attempt to interact with every entity in view distance
# hook_entity_move(){ 
# 	eid=$1
# 	$0 $eid $ARM_RIGHT 0
# }
# (eid, arm: arm_left | arm_right, sneaking: 0 | 1)
pkt_interact(){
	pkt=$(tovarint $1)
	pkt+=$(tovarint 0) # enum for "innteract"
	pkt+=$(tovarint $2)
	pkt+=$(tobool $3)
	send_packet 10 "$pkt"

}

### attack an entity
# # attempt to attack every entity in view distance
# pkt_hook_entity_move(){ 
# 	eid=$1
# 	$0 $eid
# }
# (eid)
pkt_attack(){
	pkt=$(tovarint $1)
	pkt+=$(tovarint 1) # enum for "attack"
	pkt+="00" # "sneaking" i don't know why it needs to know this, but ok

	send_packet 10 "$pkt"
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
pkt_drop(){
	get_seqid
	pkt=$(tovarint $1)      # enum for "drop item"
	pkt+=$(encode_position 0 0 0) # it's always 000, idk why
	pkt+=$(tovarint $FACE_BOTTOM) # facing -Y, always
	
	pkt+=$(tovarint $SEQ_ID)
	send_packet 1d "$pkt"
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
pkt_dig(){
	get_seqid
	pkt=$(tovarint $1)
	pkt+=$(encode_position "$2" "$3" "$4")
	pkt+=$(tovarint $5) 
	pkt+=$(tovarint $SEQ_ID)
	send_packet 1d "$pkt"
	incrm_seqid
}

SNEAK=0
UNSNEAK=1
### sneak or unsneak
# (SNEAK|UNSNEAK)
pkt_sneak(){
	get_seqid
	pkt=$(tovarint $(<$PLAYER/eid)) # player entity id
	pkt+=$(tovarint $1)                   # enum for sneak
	pkt+=$(tovarint $SEQ_ID)
	send_packet 1e "$pkt"
	incrm_seqid
}


pkt_use_item_on(){
	send_packet 31 "$(tovarint 0)$(encode_position 337 49 49)$(tovarint 1)000000000000000000000000000$(tovarint 23)"
}
