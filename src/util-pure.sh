# shellcheck shell=ksh
#
# these are implementations of the functions in util.sh, without using any external utilities
# this should NOT be used, they are hilariously slow. just fun though


readn(){
	count=$1
	if (( count == 0 )); then return; fi

	while IFS= read -r -n1 -d $'\0' ch; do
		if [ -n "$ch" ]; then
			echosafe "$ch"
		else
			echo -en "\0"
		fi

		if (( $((--count)) == 0 )); then break; fi
	done
}


fromhex() {
  while IFS= read -r -n2 ch; do
    echo -en "\x$ch"
	done
}

tohex(){

	while IFS= read -r -n1 -d $'\0' ch; do
		if [ -n "$ch" ]; then
      printf "%02x" "'$ch"
		else
			echo -n "00"
		fi
	done
	echo
}


