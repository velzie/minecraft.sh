# shellcheck shell=bash


# read $1 bytes
readn(){
	# head "-c$1"
	count=$1

	while IFS= read -r -n1 -d $'\0' ch; do
		if (( $((count--)) == 0 )); then break; fi
		if [ -n "$ch" ]; then
			echosafe "$ch"
		else
			echo -en "\0"
		fi

	done
}

# delete $1 bytes
eatn(){
	readn "$1" >/dev/null
}

# (bytes: number) -> hex string
readhex() {
	readn "$1" | tohex
}

echosafe(){
	printf "%s" "$1"
}

# hex | -> binary
fromhex() {
	xxd -p -r -c999999
}

# binary | -> hex
tohex() {
	xxd -p
}
