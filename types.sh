2varint() {
	local a
	local b
	local c
	local out
	out=$(printf '%02x' "$1")
	if [[ $1 -lt 128 ]]; then
		:
	elif [[ $1 -lt 16384 ]]; then
		a=$(($1%128))
		b=$(($1/128))
		out=$(printf "%02x" $((a+128)))$(printf "%02x" $b)
	elif [[ $1 -lt $((128*128*128)) ]]; then
		a=$(($1%128))
		c=$((($1/128)%128))
		b=$(($1/16384))
		out=$(printf "%02x" $((a+128)))$(printf "%02x" $((c+128)))$(printf "%02x" $b)
	fi
	echo -n "$out"
}

varint2() {
	local x
	local uwu
	local out
	out=""
	x=1	
	while true; do
		uwu=$(dd count=1 bs=1 status=none | xxd -p)
	
		out=$((out+((0x$uwu&127)*x)))
		x=$((x*128))
		if [[ $((0x$uwu>>7)) == 0 ]]; then
			break
		fi
	done
	echo -n "$out"
}
2string(){
	echo -n "$(2varint $(expr length $1))$(echo -n $1 | hex)"
}


repeat() {
	printf -- "$2%.0s" $(seq 1 $1)
}

unhex() {
	xxd -p -r -c999999
}
hex(){
  xxd -p
}


2short(){
	printf "%04x" $1
}
2long(){
	printf "%08x" $1
}
