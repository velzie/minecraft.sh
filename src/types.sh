# shellcheck shell=bash

# (number) -> hex
tovarint() {
	out=$(printf '%02x' "$1")
	if [[ $1 -lt 128 ]]; then
		:
	elif [[ $1 -lt 16384 ]]; then
		a=$(($1 % 128))
		b=$(($1 / 128))
		out=$(printf "%02x" $((a + 128)))$(printf "%02x" $b)
	elif [[ $1 -lt $((128 * 128 * 128)) ]]; then
		a=$(($1 % 128))
		c=$((($1 / 128) % 128))
		b=$(($1 / 16384))
		out=$(printf "%02x" $((a + 128)))$(printf "%02x" $((c + 128)))$(printf "%02x" $b)
	fi
	echo -n "$out"
}

# binary | -> number
fromvarint() {
	out=""
	x=1
	while true; do
		uwu=$(readn 1 | tohex)

		out=$((out + ((0x$uwu & 127) * x)))
		x=$((x * 128))
		if [[ $((0x$uwu >> 7)) == 0 ]]; then
			break
		fi
	done
	echo -n "$out"
}

# (string) -> hex
tostring() {
	echo -n "$(tovarint $(expr length "$1"))$(echosafe "$1" | tohex)"
}

# (number) -> hex
toshort() {
	printf "%04x" "$1"
}

# (0 | 1) -> hex
tobool() {
	printf "%02x" "$1"
}

# (number) -> hex
tolong() {
	printf "%08x" "$1"
}

# convert ieee754 single-precision float to decimal string
# (hex) -> string
fromfloat() {
	# [todo] don't use gdb as a fucking calculator
	gdb --batch -ex "print/f (float *) 0x$1" | tail -c+6
}

# (hex)
# sets x, y, z
decode_position() {
	x=$((0x$1 >> 38))
	y=$((0x$1 & 0xFFF))
	z=$(((0x$1 >> 12) & 0x3FFFFFF))
	
	[[ $x -gt 33554431 ]] && x=$((x-67108864))
	[[ $y -gt 2047 ]] && y=$((y-4095))
	[[ $z -gt 33554431 ]] && z=$((z-67108864))
}

# (x,y,z) -> hex
encode_position() {

	x=$1
	y=$2
	z=$3

	[[ $x -lt 33554433 ]] && x=$((x+67108864))
	[[ $y -lt 2049 ]] && y=$((y+4096))
	[[ $z -lt 33554433 ]] && z=$((z+67108864))
	
	printf "%016x" $((((x & 0x3FFFFFF)<<38) | ((z & 0x3FFFFFF)<<12) | (y & 0xFFF)))
}
