# shellcheck shell=bash


# read $1 bytes
readn(){
	head "-c$1"
}

# delete $1 bytes
eatn(){
	readn "$1" >/dev/null
}

# (bytes: number) -> hex string
readhex() {
	readn "$1" | tohex
}

# (repetitions: number, string) -> string
repeat() {
	printf -- "$2%.0s" $(seq 1 $1)
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
