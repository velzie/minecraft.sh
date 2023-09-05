# shellcheck shell=ksh
source src/minecraft.sh
m_cleanup_on_exit

# mutexes! in bash!
# 2 processes writing to stdout gets messy
# if a second job tries to acquire the mutex before it's unlocked it will hang until so
mutex_acquire(){
  if [ ! -p "$PLAYER/chatmutex" ]; then
    mkfifo "$PLAYER/chatmutex" || :<"$PLAYER/chatmutex"
  else
    :<"$PLAYER/chatmutex"
  fi
}
mutex_unlock(){
  ( :<"$PLAYER/chatmutex" ) &
  :>"$PLAYER/chatmutex"
  rm -f "${PLAYER:?}/chatmutex"
}

rerender(){
  printf "\033[40;1;31m"
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
    printf "\033[35m"
    echo -n "Run command: "
  else

    printf "\033[1;31m"
    echo -n "Say: "
  fi

  printf "\033[34m"
  cat "$PLAYER/chatbuf"
}

pkt_hook_chat(){

  mutex_acquire
	username=$(echosafe "$4" | fromhex | jq -r ".insertion")


  echo -en "\033[$(( $(tput lines) ));1f"
	echo
	echo -n " <$username> "
	echosafe "$2" | fromhex
	rerender
	mutex_unlock
}
pkt_hook_disguised_chat(){
  mutex_acquire
  echo -en "\033[$(( $(tput lines) ));1f"
	echo
  echo -n " [Server] "
  echosafe "$1" | fromhex | jq -r ".text"
  rerender
	mutex_unlock
}

pkt_hook_system_chat(){
  mutex_acquire
  echo -en "\033[$(( $(tput lines) ));1f"
	echo
	translate=$(echosafe "$1" | fromhex | jq -r ".translate")
	echo -n " $translate"
	rerender
	mutex_unlock
}
start_login
wait_on_login
:>"$PLAYER/chatbuf"
stty -echo
tput civis
printf "\033[40;1;31m"
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
      tput cvvis
      stty echo
      exit
      ;;
    $'\x1b' | $'\x7f') # larrow | backspace
      sed -i '$ s/.$//' "$PLAYER/chatbuf"
      ;;
    *) 
      echo -n "$char" >>"$PLAYER/chatbuf"
      ;;
  esac
  mutex_acquire
  rerender
  mutex_unlock
done
tput cvvis
stty echo
