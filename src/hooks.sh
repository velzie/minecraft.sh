# shellcheck shell=ksh
# these are the definitions for each hook function. for actual uses of these, check ../examples/demohooks.sh

### called after login and the state switches to "play"
### it is NOT safe to send packets until this function is called
# (username:string)
pkt_hook_login() {
  :
}

### called whenever an entity in render distance moves
# (eid)
pkt_hook_entity_move() {
  :
}
### called whenever a chat message is sent
# (uuid, message: hex string, timestamp: hex long, metadata: json string as hex)
pkt_hook_chat() {
  :
}

### called when the player dies in any way
### unless you have a reason not to, you should call pkt_respawn inside the hook
# (reason: json string as hex)
pkt_hook_combat_death() {
  :
}

### called whenever the player's health changes
# # attempt to leave when health falls below THRESHOLD
# $0 () {
#	  if (( $(echo "$1 $THRESHOLD" | awk '{print ($1 < $2)}') )); then
#		  echo "health was $1, leaving!"
#		  disconnect
#	  fi
# }
# (health: decimal string, food: int, saturation: decimal string)
pkt_hook_set_health() {
  :
}

### called whenever an unhandled packet gets processed
# $0 () {
#   case $pkt_id in
#     24) # "24" would be the packet name in hex
#       a=$(fromvarint)
#       b=$(readhex 4)
#       # etc etc
#     ;;
#   esac
# }
# sets "pkt_id", data is read from stdin
pkt_hook_unknown() {
  :
}

### called whenever an entity enters view distance (NOT A PLAYER)
# (eid)
pkt_hook_entity_spawn() {
  :
}

### called whenever a player enters view distance
# (eid)
pkt_hook_player_spawn() {
  :
}

### called whenever an entity (OR PLAYER) is removed or exits view distance
### the entity directory gets deleted immediately after the hook exits
# (eid)
pkt_hook_entity_remove() {
  :
}

### called when the server kicks you for any reason
### this is differnt from pkt_hook_disconnect because it only fires when the server kicks you, not if you lose connection for unrelated reasons
# echo -n "kicked from server: "
#	echosafe "$1" | fromhex
#	echo
#	(reason: json string as hex)
pkt_hook_kicked() {
  :
}

### called when the underlying TCP connection to the server closes, after pkt_hook_kicked
pkt_hook_disconnect() {
  :
}
