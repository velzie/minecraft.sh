source src/minecraft.sh
source examples/demohooks.sh
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

THRESHOLD="7.0"
# attempt to leave when health falls below THRESHOLD
pkt_hook_set_health(){
	if (( $(echo "$1 $THRESHOLD" | awk '{print ($1 < $2)}') )); then
		echo "health was $1, leaving!"
		disconnect
	fi
} 	

login

tail -f /dev/null
