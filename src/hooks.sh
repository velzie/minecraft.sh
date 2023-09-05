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

### called whenever a player chat message is sent
# (uuid, message: hex string, timestamp: hex long, metadata: json string as hex)
pkt_hook_chat() {
  :
}

### called whenever the system sends you a chat event
### player death, running an invalid command, actionbar, etc
# (metadata: json string as hex)
pkt_hook_system_chat(){
  :
}

### called on certain types of chat events, i don't know which ones
### not entirely sure what the arguments mean
# (message: hex string, typename: hex string, hasname: 0 | 1, name: hex string)"
pkt_hook_disguised_chat(){
  :
}

### called whenever the player joins the game or is teleported
### after this packet, player position will be accessible inside $PLAYER/x, $PLAYER/y, etc
# (x: decimal string, y: decimal string, z: decimal string)
pkt_hook_synchronize_player_position(){
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
