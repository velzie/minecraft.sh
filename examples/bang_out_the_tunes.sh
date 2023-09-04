. src/minecraft.sh
. examples/demohooks.sh
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT


# if noteblocks exist at these coordinates, this example will attempt to play them
BLOCKS=("-4 81 3" "-4 81 1" "-5 82 1" "-5 82 0" "-5 81 -1")

# if i was good at these sort of things i would have tried to make a rickroll thingy but oh well



# reconnect on disconnect or timeout
USERNAME=neil

pkt_hook_disconnect(){
	start_login
	echo "---- disconnected from server ----"
}

start_login


randsleep(){
  sleep $(( $(shuf -i 1-100 -n 1) / 75 ))
}

while true; do
	wait_on_login
	for block in "${BLOCKS[@]}"; do
	  pkt_dig $DIG_START $block $FACE_TOP
	  pkt_dig $DIG_CANCEL $block $FACE_TOP
	  randsleep
	done
	randsleep
done
