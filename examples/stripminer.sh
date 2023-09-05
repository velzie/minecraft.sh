# shellcheck shell=ksh
source src/minecraft.sh
source examples/demohooks.sh

m_cleanup_on_exit
DELAY=0.25


start_login

sleep 4
while true; do
	wait_on_login
	m_get_player_pos

  for i in {0..2}; do
    for j in {0..1}; do
	    m_mine_relative "$i" "$j" 0 "$DELAY"
	    m_mine_relative "$i" "$j" 0 "$DELAY"
	  done
  done

  for i in {0..4}; do
	    m_move_relative 1 0 0
	    sleep 0.1
  done


  for i in {1..3}; do
	  m_mine_relative -1 1 "$i" "$DELAY"
	  m_mine_relative -1 1 "$i" "$DELAY"
  done
  for i in {1..3}; do
	  m_mine_relative -1 1 "-$i" "$DELAY"
	  m_mine_relative -1 1 "-$i" "$DELAY"
  done

	sleep 0.1
done

