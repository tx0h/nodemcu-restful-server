local verb, id, payload = ...
local content = {}

content['verb'] = verb

if(id ~= nil) then
    content['id'] = id
end

if(payload) then
    content['payload'] = cjson.decode(payload)
end

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

if(verb == 'PUT') then
    local gpio = cjson.decode(tostring(content['payload']['gpio']))
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
    
    local update_gpios = cjson.decode(line)
    update_gpios[content['id']*1] = gpio[1]

    open_file('gpio.json', 'w+')
    file.writeline(cjson.encode(update_gpios))
    close_file()
end

return cjson.encode(content), 'application/json'
