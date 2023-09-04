# shellcheck shell=ksh


# read $1 bytes
readn(){
	head "-c$1"
}

# delete $1 bytes
eatn(){
	readn "$1" >/dev/null
}

# (repetitions: number, string) -> string
repeat() {
	printf -- "$2%.0s" $(seq 1 $1)
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

# zlib | -> 
fromlz(){
	zlib-flate -uncompress 
}
tolz(){
	zlib-flate -compress
}
