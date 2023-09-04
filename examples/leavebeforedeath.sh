source src/minecraft.sh
source examples/demohooks.sh
m_cleanup_on_exit

THRESHOLD="7.0"
# attempt to leave when health falls below THRESHOLD
pkt_hook_set_health(){
	if (( $(echo "$1 $THRESHOLD" | awk '{print ($1 < $2)}') )); then
		echo "health was $1, leaving!"
		# to ensure we get kicked as soon as possible, try to attack ourself (invalid ID)
		pkt_attack "$(<$PLAYER/eid)"
		disconnect
	fi
} 	

mc_login

tail -f /dev/null
