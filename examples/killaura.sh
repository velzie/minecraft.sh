. src/minecraft.sh
. examples/demohooks.sh
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

# list of every hostile mob type
ENTITIES_TO_TARGET="7|12|19|23|25|27|30|31|42|46|47|50|51|62|71|73|74|80|95|97|107|111|112|113|114|117|118|121|122"

start_login



while true; do
	wait_on_login
	for path in "$ENTITIES/"*; do
		eid=${path##*\/}

		# make sure we aren't going to accidentally attack ourselves (instant kick)
		if [ "$eid" != "*" ] && [ $(<$PLAYER/eid) != $eid ] && [[ "$(<$path/type)" =~ $ENTITIES_TO_TARGET ]]; then
	  	pkt_attack $eid
	  	# we don't *need* to send the arm swing packet but it looks cool
   		pkt_swing_arm $ARM_RIGHT
		fi
	done
	sleep 1
done
