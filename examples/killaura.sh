source src/minecraft.sh
source examples/demohooks.sh
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# note: may accidentally target invalid entities and get kicked

pkt_hook_entity_move(){
	local eid=$1
	if [ ! -z $eid ] && [ ! $(<$PLAYER/eid) = $eid ]; then
	  pkt_attack $eid
    pkt_swing_arm $ARM_RIGHT
    # the arm swing is optional, but it looks cool
	fi
} 	

login

tail -f /dev/null
