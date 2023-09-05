# shellcheck shell=ksh
source src/minecraft.sh

# enumerate every possible (and a few impossible) IPv4 address and check if it responds to the ping

mkdir -p /tmp/scan

for a in {1..255}; do
  for b in {1..255}; do
    for c in {1..255}; do
      for d in {1..255}; do
        echo "trying ${a}.${b}.${c}.${d}"
        {
          {
            HOST=${a}.${b}.${c}.${d}
            json=$(server_list_ping)
            name=$(echo "$json" | jq -r ".description.text")
            name=${name:-$(echo "$json" | jq -r ".description.extra[0].text")}
            if [ -n "$name" ]; then
              echo "$name" >"/tmp/scan/${a}.${b}.${c}.${d}"
              echo "players: $(echo "$json" | jq -r ".players.online")/$(echo "$json" | jq -r ".players.max")" >>"/tmp/scan/${a}.${b}.${c}.${d}"
              echo "version: $(echo "$json" | jq -r ".version.name")" >>"/tmp/scan/${a}.${b}.${c}.${d}"
            fi
          } &
          pid=$!
          sleep 1
          kill $pid
        } &
        sleep 0.05
      done
    done
  done
done


