# Discrete Event World

**Alright, this was only supposed to be a sandbox to start with but I think I should consider a domain-specific language that is much more clear than bolting on more hacky lua. The callback hell is a scoping mess and a bug factory plus it's becoming obvious that optimisation could be applied if the state information that ACTUALLY mattered were better represented in a machine format. Many events are quite independent of others and could either be replaced with more efficient equivalents or paralellised. Before I duplicate the effort I should make sure all the existing free discrete event sim stuff doesn't already do everything I need...**

Discrete event simulation containing entities that interact with each other. Intended to eventually be a testbed for video games in which the player's actions have consequences in the game world.

Early progress Lua hack. Uploaded so I don't lose it.

If you have graphviz (+sort, sed, tail) installed, it will be called hackishly by Lua every 4 years of simulation to draw the family tree of all people. If you don't... well it will probably fail, i'm not sure actually. Uncomment os.execute in world.lua.

Launch with `luajit world.lua`
