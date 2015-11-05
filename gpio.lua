local verb, id, payload = ...
local content = {}

content['verb'] = verb

if(id ~= nil) then
    content['id'] = id
end

if(payload) then
    content['payload'] = cjson.decode(payload)
end

--[[
function open_file(filename, mode)
    if(g_fileFree) then
        g_fileFree = false
        if(file.open(filename, mode)) then
            return 0
        else
            g_fileFree = true
            return -1
        end
    else
        g_fileFree = true
        return -2
    end
end

function close_file()
    file.close()
    g_fileFree = true
end
]]

if(verb == 'GET') then
    local line
    local fs = open_file('gpio.json', 'r')
    if(fs < 0) then
        if(fs == -2) then
            return '203 RESOURCE not available', 'plain/text'
        end
        return '403 RESOURCE cannot open', 'plain/text'
    end
    line = file.readline()
    close_file()
    return line, 'application/json'
end

if(verb == 'POST') then
    local fs
    local gpios = cjson.decode(tostring(content['payload']['gpios']))
    local old_gpios = nil
    
    content=cjson.encode(gpios)
    fs = open_file('gpio.json', 'r')
    if(fs < -2) then
        return '203 RESOURCE not available', 'plain/text'
    end
    if(fs == 0) then
        old_gpios = cjson.decode(file.readline())
    end
    close_file()
    
    open_file('gpio.json', 'w+')
    file.writeline(content)
    close_file()

    print('old: '..cjson.encode(old_gpios))
    print('new: '..content)
end

return cjson.encode(content), 'application/json'
