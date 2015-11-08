# nodemcu-restful-server

esp8266, nodemcu based http server with restful interface
---------------------------------------------------------

### INSTALL

Flash your esp8266 module with the nodemcu firmware and upload these files:

 * answer_request.lua
 * get_payload.lua
 * gpio.html
 * gpio.json
 * gpio.lua
 * index.html
 * luadown.png
 * restful-server.lua
 * rest.html
 * rest.lua
 * style.css

Afterwards node.compile the files restful-server.lua, answer_request.lua and get_payload.lua, after that run restful-server.lc. This will leave about 30Kb of heap memory. The other lua modules define the restful resources. To handle a restful services the resource module, a lua script, get loaded. This resource modules, loaded via loadfile, receive the HTTP verb (GET, POST, PUT and DELETE) as first argument, the second argument is the ID of an element of the resource based set. The third argument may be the payload passed via URL argument or passed via PUT or POST body. The resource module returns a payload and the mime type of the payload.

### GENERAL

The restful-server is able to handle quiet complex web pages but is also limited to the environment given settings. For instance, only one file can be opened at a time - only one file handle! This server is not bullet proofed but in it's environment it do well. You can't pass arguments to the timer callback functions and a lot of other stumbling blocks, like unfreed callback functions. nodemcu is far away from being called productive, the filesystem corrupts every now and than.

In the end, open the url http://ip-or-fqdn-of-esp/ in your browser and check&see the examples, then decide if it could be useful for your project.

### PRIVATE

This is my first & hopefully last project with lua, I learned it very quick and I hated it even quicker. If the concept of this programming language is: 'to be just different', then it is a real major in this category!

have phun,

tx0h
