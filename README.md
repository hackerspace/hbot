# hbot

**IRC bot which sole purpose is to watch dokuwiki's recent changes for updates and inform us on IRC channel.**

https://github.com/hacxman/hbot

There are a few things missing. First but the most important is configuration file support, there are only some variables and constants which should be setup before running the bot. Version published on github doesn't have these information filled in.

**Known deficits:**
* bot has to be highlighted every time when issuing commands.
* bot cannot recognize more than one update in a given timestamp (1 minute)

Bot itself is modelled after http://snippets.dzone.com/posts/show/1785 with some mods.\\
There is a primitive support for extending bot with commands and periodic tasks.

Of course it's written in Ruby,\\
*Enjoy!*

