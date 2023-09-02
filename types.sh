# shellcheck shell=bash

tovarint() {
	local a
	local b
	local c
	local out
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

fromvarint() {
	local x
	local uwu
	local out
	out=""
	x=1
	while true; do
		uwu=$(dd count=1 bs=1 status=none | xxd -p)

		out=$((out + ((0x$uwu & 127) * x)))
		x=$((x * 128))
		if [[ $((0x$uwu >> 7)) == 0 ]]; then
			break
		fi
	done
	echo -n "$out"
}
tostring() {
	echo -n "$(tovarint $(expr length "$1"))$(printf "%s" "$1" | tohex)"
}


repeat() {
	printf -- "$2%.0s" $(seq 1 $1)
}

fromhex() {
	xxd -p -r -c999999
}
tohex() {
	xxd -p
}

toshort() {
	printf "%04x" $1
}
tolong() {
	printf "%08x" $1
}
hex2bin() {
	# \o/
	echo -n "$1" | sed -E 's/0/0000/g;s/1/0001/g;s/2/0010/g;s/3/0011/g;s/4/0100/g;s/5/0101/g;s/6/0110/g;s/7/0111/g;s/8/1000/g;s/9/1001/g;s/a/1010/g;s/b/1011/g;s/c/1100/g;s/d/1101/g;s/e/1110/g;s/f/1111/g'
}
fromfloat() {
	# [todo] don't use gdb as a fucking calculator
	gdb --batch -ex "print/f (float *) 0x$1" | tail -c+6
}

decode_position() {
	x=$((0x$1 >> 38))
	y=$((0x$1 & 0xFFF))
	z=$(((0x$1 >> 12) & 0x3FFFFFF))
	
	[[ $x -gt 33554431 ]] && x=$((x-67108864))
	[[ $y -gt 2047 ]] && y=$((y-4095))
	[[ $z -gt 33554431 ]] && z=$((z-67108864))
}

encode_position() {
	local x
	local y
	local z

	x=$1
	y=$2
	z=$3

	[[ $x -lt 33554433 ]] && x=$((x+67108864))
	[[ $y -lt 2049 ]] && y=$((y+4095))
	[[ $z -lt 33554433 ]] && z=$((z+67108864))
	
	printf "%016x" $((((x & 0x3FFFFFF)<<38) | ((z & 0x3FFFFFF)<<12) | (y & 0xFFF)))
}
