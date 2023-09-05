# shellcheck shell=ksh
source src/minecraft.sh


# print MOTD, version, etc for a server

HOST=endcrystal.me
json=$(server_list_ping)
name=$(echo "$json" | jq -r ".description.text")
name=${name:-$(echo "$json" | jq -r ".description.extra[0].text")}
echo "$name"
echo "players: $(echo "$json" | jq -r ".players.online")/$(echo "$json" | jq -r ".players.max")"
echo "version: $(echo "$json" | jq -r ".version.name")"
echo "ping: ${ping}ms"
