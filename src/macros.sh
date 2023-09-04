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
