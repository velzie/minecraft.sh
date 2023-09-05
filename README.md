<h1 align="center">minecraft.sh</h1>
<p align="center"><img src="./assets/logo.png" alt="logo" height="100"></p>
<p align="center">A minecraft client/bot library written in pure bash + coreutils</p>
<div align="center">
  <a href="https://github.com/CoolElectronics/minecraft.sh"><img alt="github" src="https://img.shields.io/badge/github-coolelectronics/minecraft.sh?style=for-the-badge&labelColor=555555&logo=github&c=a" height="20"></a>
  <img src="https://img.shields.io/github/stars/CoolElectronics/minecraft.sh?" />
</div>

## Why?
I wanted to learn more about bash, maintaining libraries, and the minecraft protocol. This is mostly a learning excersize on my end.
If you were looking for an actual featured bot library, there are probably better options.

## Features

| Feature              | Supported?           |
| -------------------- | -------------------- |
| 1.20.1               | :white_check_mark:   |
| Mining               | :white_check_mark:   |
| Placing Blocks       | :white_check_mark:   |
| Entities             | :white_check_mark:   |
| Chat                 | :white_check_mark:   |
| Metadata Retrival    | :white_check_mark:   |
| Movement             | :heavy_minus_sign:   |
| Inventory Management | :heavy_minus_sign:   |
| Chunk/Biome data     | :x:                  |
| Pathfinding          | :x:                  |
| Vehicles             | :x:                  |
| Chat encryption      | :x:                  |
| Online-Mode support  | :x:                  |
| Old protocol versions| :x:                  |

## Cool demos

### Chat client (see examples/chatclient.sh)
https://github.com/CoolElectronics/minecraft.sh/assets/58010778/e1983ea0-3156-4ce5-83a1-6f085be2f1cf
### Auto-stripminer (see examples/stripminer.sh)
https://github.com/CoolElectronics/minecraft.sh/assets/58010778/29641d51-603f-4c0e-b031-7dbf324000e0
## How to use
minecraft.sh provides a simple high level library API for creating bots that can be easily used in any shell script. For example, here's a simple bot that will automatically "strip mine" in a straight line

```bash
source src/minecraft.sh
source examples/demohooks.sh
DELAY=0.25
start_login

sleep 4
while true; do
  wait_on_login
  m_get_player_pos
  for i in {0..2}; do
    for j in {0..1}; do
      m_mine_relative "$i" "$j" 0 "$DELAY"
      m_mine_relative "$i" "$j" 0 "$DELAY"
    done
  done
  for i in {0..4}; do
    m_move_relative 1 0 0
    sleep 0.1
  done
  for i in {1..3}; do
    m_mine_relative -1 1 "$i" "$DELAY"
    m_mine_relative -1 1 "$i" "$DELAY"
  done
  for i in {1..3}; do
    m_mine_relative -1 1 "-$i" "$DELAY"
    m_mine_relative -1 1 "-$i" "$DELAY"
  done
  sleep 0.1
done
```

More examples can be found [here](./examples), and make sure to check out the [documentation](./docs.md)

Note: ksh is recommended for running any of the examples

## Dependencies
The only non-coreutil dependencies are `zlib-flate` and `xxd`.
`zlib-flate` is optional if compression is disabled in server.properties, and if you swap out `util.sh` with `util-pure.sh` xxd is optional too.

