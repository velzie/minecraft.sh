# shellcheck shell=ksh

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
		c=$(( ( $1 / 128 ) % 128 ))
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

		out=$(( out + (( 0x$uwu & 127 ) * x )))
		x=$(( x * 128 ))
		if [[ $(( 0x$uwu >> 7 )) == 0 ]]; then
			break
		fi
	done
	echo -n "$out"
}

# (string) -> hex
tostring() {
	echo -n "$(tovarint "${#1}")$(echosafe "$1" | tohex)"
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
fromfloat(){
	# bitwise AND with the mask of all mantissa bytes set
	mantissa=$(( 0x$1 & 0x007fffff ))
	# same thing but for the exponent, also shift back 23 bytes to get back into the range
 	exponent=$(( ( ( 0x$1 & 0x7f800000 ) >> 23 ) - 127 ))
 	sign=$(( ( ( 0x$1 & 0x80000000 ) >> 31 ) * -1 ))

 	if [ "$sign" = "0" ]; then
		sign=1
 	fi

	raw=$(bc -l <<< "( 2 ^($exponent) * ( 1 + $mantissa / ( 2 ^(22) * 2 ) ) * $sign )")
	# rounding
	printf "%.4f" "$raw" | sed 's/^00*\|00*$//g'
}

# convert decimal string to ieee754 single-precision float
# decimals are fucked. try not to use them
# (string) -> hex
tofloat(){
	dec=$1

	# get sign bit
	if [ "${dec:0:1}" = "-" ]; then
		dec=${dec:1}
		sign=0x80000000
	else
		sign=0x00000000
	fi

	# 0 is "denormalized", make sure to handle it
	if (( $(echo "$dec == 0" | bc -l) )); then
		echo -n "00000000"
		return
	fi

	# get binary rep of number
	bin=$(echo "obase=2;$dec" | bc)

	if (( $(echo "$dec >= 1" | bc -l) )); then
		# cut off the first digit becuase it's assumed, and cut off all after 23 + .
		bin=${bin:1:25}
	else

		# special case: for numbers less than 1 keep the first digit and shift later
		bin="0${bin:0:23}"
	fi


	# add back the .
	case $bin in
		*"."*) ;;
		*) bin="$bin." ;;
	esac

	# use the number of decimal places to calculate the exponent after normalization
	# for example 1100.1000 has 4 bits before the decimal meaning an exponent of 3
	places=${bin%\.*}
	exponent=$(( ${#places} + 127 ))

	if (( $(echo "$dec < 1" | bc -l) )); then
		# special case for <1
		((exponent-=2))
	fi


	# shift exponent behind mantissa
	exponent=$(( exponent << 23 ))

	# extend to 23 bytes
	binlen=${#bin}
	zeros=00000000000000000000000
	toadd=$(( 24 - binlen ))
	if (( toadd < 0 )); then
		toadd=0
	fi
	bin="$bin${zeros:0:$toadd}"


	# the decimal point was just for internal reference, remove it and convert to decimal
	mantissa=$(( 2#${bin/\./} ))

	# combine everything and we're done!
	
	printf "%04x" "$(( sign | exponent | mantissa ))" 
	# time to do everything again for the double
}

# convert ieee754 double-precision float to decimal string
# (hex) -> string
fromdouble(){
	mantissa=$(( 0x$1 & 0xfffffffffffff ))
 	exponent=$(( ( ( 0x$1 & 0x7ff0000000000000 ) >> 52 ) - 1023 ))
 	sign=$(( ( 0x$1 & 0x8000000000000000 ) >> 63 ))

 	if [ "$sign" = "0" ]; then
		sign=1
 	fi

	raw=$(bc -l <<< "( 2 ^($exponent) * ( 1 + $mantissa / ( 2 ^(51) * 2 ) ) * $sign )")
	printf "%.4f" "$raw" | sed 's/^00*\|00*$//g'
}


# convert decimal string to ieee754 double-precision float
# (string) -> hex
todouble(){
	dec=$1

	if [ "${dec:0:1}" = "-" ]; then
		dec=${dec:1}
		sign=0x8000000000000000
	else
		sign=0x0000000000000000
	fi

	bin=$(echo "obase=2;$dec" | bc)
	bin=${bin:1:54}

	case $bin in
		*"."*) ;;
		*) bin="$bin." ;;
	esac

	places=${bin%\.*}
	exponent=$(( ${#places} + 1023 ))

	exponent=$(( exponent << 52 ))

	binlen=${#bin}
	zeros=0000000000000000000000000000000000000000000000000000
	toadd=$(( 53 - binlen ))
	if (( toadd < 0 )); then
		toadd=0
	fi
	bin="$bin${zeros:0:$toadd}"
	mantissa=$(( 2#${bin/\./} ))

	printf "%08x" "$(( sign | exponent | mantissa ))"
}

# (hex)
# sets x, y, z
decode_position() {
	x=$((0x$1 >> 38))
	y=$((0x$1 & 0xFFF))
	z=$(((0x$1 >> 12) & 0x3FFFFFF))

	[[ $x -gt 33554431 ]] && x=$((x - 67108864))
	[[ $y -gt 2047 ]] && y=$((y - 4095))
	[[ $z -gt 33554431 ]] && z=$((z - 67108864))
}

# (x,y,z) -> hex
encode_position() {

	x=$1
	y=$2
	z=$3

	[[ $x -lt 33554433 ]] && x=$((x + 67108864))
	[[ $y -lt 2049 ]] && y=$((y + 4096))
	[[ $z -lt 33554433 ]] && z=$((z + 67108864))

	printf "%016x" $((((x & 0x3FFFFFF) << 38) | ((z & 0x3FFFFFF) << 12) | (y & 0xFFF)))
}
