# Documentation
  

# List of methods and hooks
auto-generated from comments by ./docsgen.sh
## pkt_hook_login()
called after login and the state switches to "play" 	
it is NOT safe to send packets until this function is called 	
### arguments
`(username:string)`

## pkt_hook_entity_move()
called whenever an entity in render distance moves 	
### arguments
`(eid)`

## pkt_hook_chat()
called whenever a chat message is sent 	
### arguments
`(uuid, message: hex string, timestamp: hex long, metadata: json string as hex)`

## pkt_hook_combat_death()
called when the player dies in any way 	
unless you have a reason not to, you should call pkt_respawn inside the hook 	
### arguments
`(reason: json string as hex)`

## pkt_hook_set_health()
called whenever the player's health changes 	
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
called whenever an unhandled packet gets processed 	
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

## pkt_respawn()
respawn the player after a death 	

## pkt_chat()
sends a message in public chat 	
### arguments
`(message: string)`
### example
```bash 	
pkt_chat "hello! I sent a chat message!" 	
```

## pkt_chat_command()
runs a server command 	
note: there is currently no way to recieve the feedback after the command 	
### arguments
`(command: string)`
### example
```bash 	
pkt_chat_command "kill CoolElectronics" 	
```

## pkt_swing_arm()
swings the player arm 	
### arguments
`(arm: ARM_LEFT | ARM_RIGHT)`
### example
```bash 	
pkt_swing_arm $ARM_RIGHT 	
```

## pkt_interact()
interact with an entity 	
in the standard client, this happens when right clicking something (mounting a horse, trading with a villager, etc) 	
### arguments
`(eid, arm: arm_left | arm_right, sneaking: 0 | 1)`
### example
```bash 	
# attempt to interact with every entity in view distance 	
hook_entity_move(){ 	
	local eid=$1 	
	pkt_interact $eid $ARM_RIGHT 0 	
} 	
```

## pkt_attack()
attack an entity 	
### arguments
`(eid)`
### example
```bash 	
# attempt to attack every entity in view distance 	
pkt_hook_entity_move(){ 	
	local eid=$1 	
	pkt_attack $eid 	
} 	
```

## pkt_drop()
drop the currently held item 	
### arguments
`(DROP_ITEM|DROP_STACK)`

## pkt_dig()
attempt to mine a block 	
### arguments
`(DIG_START | DIG_CANCEL | DIG_FINISH, x, y, z, face)`
### example
```bash 	
pkt_dig $DIG_START 12 50 14 	
sleep 4 # wait for enough time to mine the block 	
pkt_dig $DIG_FINISH 12 50 14 	
```

## pkt_sneak()
sneak or unsneak 	
### arguments
`(SNEAK|UNSNEAK)`

