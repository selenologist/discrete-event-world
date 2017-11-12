# Discrete Event World

Discrete event simulation containing entities that interact with each other. Intended to eventually be a testbed for video games in which the player's actions have consequences in the game world.

Early progress Lua hack. Uploaded so I don't lose it.

If you have graphviz (+sort, sed, tail) installed, it will be called hackishly by Lua every 4 years of simulation to draw the family tree of all people. If you don't... well it will probably fail, i'm not sure actually. Uncomment os.execute in world.lua.

Launch with `luajit world.lua`
