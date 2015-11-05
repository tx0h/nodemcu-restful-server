local verb, id, payload = ...
local content = {}

content['verb'] = verb

if(id ~= nil) then
    content['id'] = id
end

if(payload) then
    content['payload'] = cjson.decode(payload)
end

return cjson.encode(content), 'application/json'
