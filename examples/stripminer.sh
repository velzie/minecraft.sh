source src/minecraft.sh
source examples/demohooks.sh

m_cleanup_on_exit
DELAY=0.1


start_login

mine_relative(){
  pkt_dig $DIG_START "$(( ${x%.*} + "$1" ))" "$(( ${y%.*} + "$2" ))" "$(( ${z%.*} + "$3" ))" $FACE_TOP
  sleep "$DELAY"
  pkt_dig $DIG_FINISH "$(( ${x%.*} + "$1" ))" "$(( ${y%.*} + "$2" ))" "$(( ${z%.*} + "$3" ))" $FACE_TOP
}

move_relative(){
  m_get_player_pos
  pkt_set_position "$(echo "${x%.*}.5 + $1" | bc -l )" "$(echo "${y%.*} + $2" | bc -l )" "$(echo "${z%.*}.5 + $3" | bc -l )" 1
}

sleep 4
while true; do
	wait_on_login
	m_get_player_pos


  for i in {0..2}; do
    for j in {0..1}; do
	    mine_relative "$i" "$j" 0
	    mine_relative "$i" "$j" 0
	  done
  done

  for i in {0..4}; do
	    move_relative 1 0 0
	    sleep 0.2
  done


  for i in {1..3}; do
	  mine_relative -1 1 "$i"
	  mine_relative -1 1 "$i"
  done
  for i in {1..3}; do
	  mine_relative -1 1 "-$i"
	  mine_relative -1 1 "-$i"
  done

	sleep 0.1
done

