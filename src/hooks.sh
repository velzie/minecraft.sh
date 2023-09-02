# these are the definitions for each hook function. for actual uses of these, check ../examples/demohooks.sh


### called after login and the state switches to "play"
### it is NOT safe to send packets until this function is called
# (username:string)
pkt_hook_login(){
  :
}

### called whenever an entity in render distance moves
# (eid)
pkt_hook_entity_move(){

}
### called whenever a chat message is sent
# (uuid, message: hex string, timestamp: hex long, metadata: json string as hex)
pkt_hook_chat(){
	:
}

### called when the player dies in any way
### unless you have a reason not to, you should call pkt_respawn inside the hook
# (reason: json string as hex)
pkt_hook_combat_death(){
  :
}

### called whenever the player's health changes
# # attempt to leave when health falls below THRESHOLD
# $0 (){
#	  if (( $(echo "$1 $THRESHOLD" | awk '{print ($1 < $2)}') )); then
#		  echo "health was $1, leaving!"
#		  disconnect
#	  fi
# } 	
# (health: decimal string, food: int, saturation: decimal string)
pkt_hook_set_health(){
  :
}
