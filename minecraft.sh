. ./types.sh
PORT=25565

hexpacket_len() {
	2varint $((($(echo -n "$1" | unhex | wc -c)+1)))
}
send_packet(){
  echo -n "$(hexpacket_len "$2")$1$2" | unhex >&3
}
# read from stdin(bytes)
readhex(){
	head -c $1 | hex
}


login(){

	# ensure we're the only one
	lsof -t lsof | xargs kill
	exec 4<>lsof
	exec 3<>/dev/tcp/localhost/$PORT


	STATE=0
	send_packet 00 "$(2varint 763)$(2string localhost)$(2short $PORT)$(2varint 2)"
	send_packet 00 "$(2string sh)00"

# 	sleep 2
#
# 	# while true; do
# 	# sleep 1
# # done

	listen<&3&
	
}

listen(){
	STATE=2
	# 0: handshaking
	# 1: pinging
	# 2: login
	# 3: play	
	

	if [[ ! -p tcp ]]; then
		mkfifo tcp
	fi

while true; do

	len=$(varint2)
	

	head -c $len<&3>tcp&
	proc_pkt<tcp


	# if ! head -c $len | proc_pkt; then
	# 	echo "disconnected"
	# 	return
	# fi
#
# 	a=$(dd count=$len bs=1 status=none | hex)
#
# 	if [[ "$a" == '' ]]; then
# 		echo "guh"
# 		return
# 	fi
#
#
# 	if [[ $a == "02"* ]]; then
# 		echo "logged in"
# 		uuid=${a:0:32}
# 		echo "i am $uuid"
# 		name=$(echo ${a:32:48}|unhex)
# 		echo "am $name"
# 	fi
# 	if [[ $a == "23"* ]]; then
# 		id=${a:2}
# 		echo "keepalive $id"
# 		send_packet 12 "$id">&3
# 	elif [[ $a == "35"* ]]; then
# 		echo "chat!"
# 		uuid=${a:0:32}
# 		echo $uuid
# 	fi
done
}

proc_pkt(){
	pkt_id=$(readhex 1)
	if [ "$pkt_id" == "" ]; then
		echo "exitng"
		exit
		return 1
	fi

	case $STATE in
		0) ;;
		1) ;;
		2) 
			case $pkt_id in
				00)
					echo "Failed to login"
					# print the disconnect reason
					cat
					return 1
				;;
				02)

					uuid=$(readhex 16)
					len=$(varint2)
					read -n$len username
					echo "logged in as $username"
					STATE=3
					pkt_respawn
				;;
			esac
			;;
		3)
			case $pkt_id in
				23)
					id=$(readhex 9999)
					echo "keepalive packet $id"
					send_packet 12 "$id"
				;;
				35)
					uuid=$(readhex 16)
					index=$(varint2) # unknown what this does
					head -c 1 >/dev/null # eat the signature bool 
					len=$(varint2)
					message=$(head -c $len)
					timestamp=$(readhex 8)
					salt=$(readhex 8) # crypto related? idk
					unknown=$(readhex 6) # no idea what this is

					username=$(jq -r ".insertion") # i don't technically *need* jq but it's easy


					echo "<$username> $message"
				;;
				38)
					id=$(varint2)
					len=$(varint2)
					reason=$(jq -r ".translate")
					echo "died! $reason"
					pkt_respawn
				;;
				*)
					# echo "unknown packet $pkt_id"
				;;
			esac
		;;
	esac
	cat>/dev/null
}


pkt_respawn(){
	send_packet 07 "$(2varint 0)"
}


pkt_chat(){
	pkt=$(2string $1) # message
	pkt+=$(2long $(date +%s)) # timestamp
	pkt+=$(2long $(date +%s)) # salt
	pkt+="00" # has signature, bool(false)
	pkt+="$(2varint 1)" # message count? idk what this means
	pkt+="$(repeat 11 '00')" # "acknowleged"?? no idea what this is either but if i spam exactly 11 zeros it seems to work
	send_packet 05 "$pkt"
}
pkt_chat_command(){
	pkt=$(2string $1) # message
	pkt+=$(2long $(date +%s)) # timestamp
	pkt+=$(2long $(date +%s)) # salt
	pkt+=$(2varint 0) # idk some crypto bullshit
	pkt+=$(2varint 1) # message count
	pkt+="$(repeat 11 '00')" # "acknowleged"
	send_packet 04 "$pkt"
}
