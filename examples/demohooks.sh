# shellcheck shell=bash


# a lot of these hook functions will pass a string as hex.
# this is to avoid the deletion of nul bytes that bash will automatically do



pkt_hook_login(){
	echo "logged in as $1"
	pkt_respawn
}

pkt_hook_chat(){
	username=$(echosafe "$4" | fromhex | jq -r ".insertion") # i don't technically *need* jq but it's easy

  # make sure not to mangle nul bytes
	echo -n "<$username> "
	echosafe "$2" | fromhex
	echo
}

pkt_hook_combat_death(){
	reason=$(echosafe "$1" | fromhex | jq -r ".translate")
	echo "died! $reason"
	pkt_respawn
}

pkt_hook_set_health(){
	echo "health: $1, food: $2, saturation: $3"
}

pkt_hook_player_spawn(){
	echo "player $eid spawned"
}

pkt_hook_disconnect(){
	echo "---- disconnected from server ----"
}
pkt_hook_kicked(){
	echo -n "kicked from server: "
	echosafe "$1" | fromhex
	echo
}
