# small utility functions


### stores player position in "x" "y" and "z"
m_get_player_pos(){
	x=$(<"$PLAYER/x")
	y=$(<"$PLAYER/y")
	z=$(<"$PLAYER/z")
	x=${x:-0}
	y=${y:-0}
	z=${z:-0}
}

### terminates all jobs on exit
m_cleanup_on_exit(){
	trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT
}

### mine block XYZ bocks relative to the player
### "delay" is the number of seconds it should take to fully mine the block
# (x,y,z,delay)
m_mine_relative(){
  pkt_dig "$DIG_START" "$(( ${x%.*} + "$1" ))" "$(( ${y%.*} + "$2" ))" "$(( ${z%.*} + "$3" ))" "$FACE_TOP"
  sleep "$4"
  pkt_dig "$DIG_FINISH" "$(( ${x%.*} + "$1" ))" "$(( ${y%.*} + "$2" ))" "$(( ${z%.*} + "$3" ))" "$FACE_TOP"
}

### moves XYZ blocks relative to the current location
# (x,y,z)
m_move_relative(){
  m_get_player_pos
  pkt_set_position "$(echo "${x%.*}.5 + $1" | bc -l )" "$(echo "${y%.*} + $2" | bc -l )" "$(echo "${z%.*}.5 + $3" | bc -l )" 1
}
