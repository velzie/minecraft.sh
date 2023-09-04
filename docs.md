# Documentation
  

# List of methods and hooks
auto-generated from comments by ./docsgen.sh
## pkt_hook_login()
called after login and the state switches to "play"<br/> 	
it is NOT safe to send packets until this function is called 	
### arguments
`(username:string)`

## pkt_hook_entity_move()
called whenever an entity in render distance moves<br/> 	
### arguments
`(eid)`

## pkt_hook_chat()
called whenever a player chat message is sent<br/> 	
### arguments
`(uuid, message: hex string, timestamp: hex long, metadata: json string as hex)`

## pkt_hook_system_chat()
called whenever the system sends you a chat event<br/> 	
player death, running an invalid command, actionbar, etc 	
### arguments
`(metadata: json string as hex)`

## pkt_hook_disguised_chat()
called on certain types of chat events, i don't know which ones<br/> 	
### arguments
`not sure what the arguments mean`

## pkt_hook_synchronize_player_position()
called whenever the player joins the game or is teleported<br/> 	
after this packet, player position will be accessible inside $PLAYER/x, $PLAYER/y, etc 	
### arguments
`(x: decimal string, y: decimal string, z: decimal string)`

## pkt_hook_combat_death()
called when the player dies in any way<br/> 	
unless you have a reason not to, you should call pkt_respawn inside the hook 	
### arguments
`(reason: json string as hex)`

## pkt_hook_set_health()
called whenever the player's health changes<br/> 	
### arguments
`(health: decimal string, food: int, saturation: decimal string)`
### example
```bash 	
# attempt to leave when health falls below THRESHOLD 	
pkt_hook_set_health () { 	
  if (( $(echo "$1 $THRESHOLD" | awk '{print ($1 < $2)}') )); then 	
	  echo "health was $1, leaving!" 	
	  disconnect 	
  fi 	
} 	
```

## pkt_hook_unknown()
called whenever an unhandled packet gets processed<br/> 	
### arguments
`sets "pkt_id", data is read from stdin`
### example
```bash 	
pkt_hook_unknown () { 	
  case $pkt_id in 	
    24) # "24" would be the packet name in hex 	
      a=$(fromvarint) 	
      b=$(readhex 4) 	
      # etc etc 	
    ;; 	
  esac 	
} 	
```

## pkt_hook_entity_spawn()
called whenever an entity enters view distance (NOT A PLAYER)<br/> 	
### arguments
`(eid)`

## pkt_hook_player_spawn()
called whenever a player enters view distance<br/> 	
### arguments
`(eid)`

## pkt_hook_entity_remove()
called whenever an entity (OR PLAYER) is removed or exits view distance<br/> 	
the entity directory gets deleted immediately after the hook exits 	
### arguments
`(eid)`

## pkt_hook_kicked()
called when the server kicks you for any reason<br/> 	
this is differnt from pkt_hook_disconnect because it only fires when the server kicks you, not if you lose connection for unrelated reasons 	
### arguments
`(reason: json string as hex)`
### example
```bash 	
echo -n "kicked from server: " 	
echosafe "$1" | fromhex 	
echo 	
```

## pkt_hook_disconnect()
called when the underlying TCP connection to the server closes, after pkt_hook_kicked<br/> 	

## m_get_player_pos()
stores player position in "x" "y" and "z"<br/> 	

## m_cleanup_on_exit()
terminates all jobs on exit<br/> 	

## m_mine_relative()
mine block XYZ bocks relative to the player<br/> 	
"delay" is the number of seconds it should take to fully mine the block 	
### arguments
`(x,y,z,delay)`

## m_move_relative()
moves XYZ blocks relative to the current location<br/> 	
### arguments
`(x,y,z)`

## send_packet()
send a raw serverbound packet<br/> 	
### arguments
`(packet_num: hex(2), data: hex)`
### example
```bash 	
send_packet 2f "$(tovarint 1)" 	
# "2f" is the serverbound packet id for "swing arm" and 1 here means "left hand" 	
# see the full list of packets at https://wiki.vg/Protocol 	
```

## pkt_respawn()
respawn the player after a death<br/> 	
### arguments
`}`
### example
```bash 	
pkt_hook_combat_death() { 	
	pkt_respawn 	
```

## pkt_chat()
sends a message in public chat<br/> 	
### arguments
`(message: string)`
### example
```bash 	
pkt_chat "hello! I sent a chat message!" 	
```

## pkt_chat_command()
runs a server command<br/> 	
the command response is recieved in pkt_hook_system_chat 	
### arguments
`(command: string)`
### example
```bash 	
pkt_chat_command "kill CoolElectronics" 	
```

## pkt_swing_arm()
swings the player arm<br/> 	
### arguments
`(arm: ARM_LEFT | ARM_RIGHT)`
### example
```bash 	
pkt_swing_arm $ARM_RIGHT 	
```

## pkt_interact()
interact with an entity<br/> 	
in the standard client, this happens when right clicking something (mounting a horse, trading with a villager, etc) 	
### arguments
`(eid, arm: arm_left | arm_right, sneaking: 0 | 1)`
### example
```bash 	
# attempt to interact with every entity in view distance 	
hook_entity_move(){ 	
	eid=$1 	
	pkt_interact $eid $ARM_RIGHT 0 	
} 	
```

## pkt_attack()
attack an entity<br/> 	
### arguments
`(eid)`
### example
```bash 	
# attempt to attack every entity in view distance whenever it moves 	
pkt_hook_entity_move(){ 	
	eid=$1 	
	pkt_attack $eid 	
} 	
```

## pkt_drop()
drop the currently held item<br/> 	
### arguments
`(DROP_ITEM|DROP_STACK)`

## pkt_dig()
attempt to mine a block<br/> 	
### arguments
`(DIG_START | DIG_CANCEL | DIG_FINISH, x, y, z, face)`
### example
```bash 	
pkt_dig $DIG_START 12 50 14 	
sleep 4 # wait for enough time to mine the block 	
pkt_dig $DIG_FINISH 12 50 14 	
```

## pkt_sneak()
sneak or unsneak<br/> 	
### arguments
`(SNEAK|UNSNEAK)`

## pkt_set_position()
teleport to a coordinate, within reason<br/> 	
### arguments
`(x: decimal string, y: decimal string, z: decimal string, onground: 0 | 1)`

## pkt_set_on_ground()
tell server if you're grounded or not<br/> 	
### arguments
`(0 | 1)`

## pkt_pick_item()
select an item from the hotbar<br/> 	
### arguments
`(item: 0-8)`

## pkt_use_item()
use item (eg, throw snowball)<br/> 	

