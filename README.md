# nodemcu-restful-server

esp8266, nodemcu based http server with restful interface
=========================================================

INSTALL
-------

Flash your esp8266 module with the nodemcu firmware and upload these files:

 * gpio.html
 * gpio.json
 * gpio.lua
 * index.html
 * LICENSE
 * luadown.png
 * README.md
 * restful-server.lua
 * rest.html
 * rest.lua
 * style.css

Afterwards compile the restful-server.lua and run restful-server.lc. This will leave about 22Kb heap. The modules define the restful resource. To handle the restful services the resource, a lua script, get loaded. This resource modules, loaded via loadfile, receive the HTTP verb (GET, POST, PUT and DELETE) as first argument, the second argument is the ID in of a resource based set. The third argument may be the payload past via url or PUT or POST body.

GENERAL
-------

The restful-server is able to handle quiet complex web pages but is also limited to the environment given settings. For instance, only one file can be opened at a time - only one file handle. This server is not bullet proofed but in it's environment it do well. You can't pass arguments to the timer callback functions and a lot of other stumbling blocks, like unfreed callback functions.

In the end, open the url http://ip-or-name-of-esp/ in your browser and check&see the examples, then decide if it could help you.

PRIVATE
-------
This is my first & hopefuly last project with lua, I learned it very quick and I hateed it even quicker. If the concept of this programming language is: 'to be just different', then it is a real major in this category!

have phun,

tx0h
