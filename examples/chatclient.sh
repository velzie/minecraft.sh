# shellcheck shell=ksh
source src/minecraft.sh
m_cleanup_on_exit

rerender(){
  echo -en "\033[1;1f"
  echo -n "╭"
  repeat "$(( $(tput cols) - 2 ))" "─"
  echo -n "╮"

  for i in $(seq "$(tput lines)"); do
    echo -en "\033[$(( i + 1 ));1f"
	  echo -n "│"
    echo -en "\033[$(( i + 1 ));$(tput cols)f"
	  echo -n "│"
  done
  echo -en "\033[3;1f├"
  repeat "$(( $(tput cols) - 2 ))" "─"
  echo -en "┤"
  echo -en "\033[2;2f"
  repeat "$(( $(tput cols) - 2 ))" " "
  echo -en "\033[2;2f"

  if [ "$(readn 1 <"$PLAYER/chatbuf")" = "/" ]; then
    echo -n "Run command: "
  else
    echo -n "Say: "
  fi
  cat "$PLAYER/chatbuf"
}

pkt_hook_chat(){
	username=$(echosafe "$4" | fromhex | jq -r ".insertion")


  echo -en "\033[$(( $(tput lines) ));1f"
	echo
	echo -n " <$username> "
	echosafe "$2" | fromhex
	rerender
}
pkt_hook_disguised_chat(){
  echo -en "\033[$(( $(tput lines) ));1f"
	echo
  echo -n " [Server] "
  echosafe "$1" | fromhex | jq -r ".text"
  rerender
}

pkt_hook_system_chat(){
  echo -en "\033[$(( $(tput lines) ));1f"
	echo
	translate=$(echosafe "$1" | fromhex | jq -r ".translate")
	echo -n " $translate"
	rerender
}
start_login
wait_on_login
:>"$PLAYER/chatbuf"
stty -echo
tput civis
clear
rerender
while true; do
  tput cvvis
  read -n1 -r char
  tput civis
  case $char in
    $'\x0d') # enter
      if [ "$(readn 1 <"$PLAYER/chatbuf")" = "/" ]; then
        # cut off /
        pkt_chat_command "$(tail -c +2 <"$PLAYER/chatbuf")"
      else
        pkt_chat "$(<"$PLAYER/chatbuf")"
      fi
      :>"$PLAYER/chatbuf"
      ;;
    $'\x03') # ctrl+c
      exit
      ;;
    $'\x1b' | $'\x7f') # larrow | backspace
      sed -i '$ s/.$//' "$PLAYER/chatbuf"
      ;;
    *) 
      echo -n "$char" >>"$PLAYER/chatbuf"
      ;;
  esac
  rerender
done
stty echo
