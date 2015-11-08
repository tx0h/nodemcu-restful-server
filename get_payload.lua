local function urldecode(s)
    s = s:gsub('+', ' '):gsub('%%(%x%x)',
        function(h)
            return string.char(tonumber(h, 16))
        end)
    return s
end

local function parseurl(s)
    local k, v
    local ans = {}
        for k,v in s:gmatch('([^&=?]-)=([^&=?]+)' ) do
        ans[ k ] = urldecode(v)
    end
    return ans
end

local function split(str, delim)
    local result,pat,lastPos = {},"(.-)" .. delim .. "()", 1
    for part, pos in string.gfind(str, pat) do
        table.insert(result, part); lastPos = pos
    end
    table.insert(result, string.sub(str, lastPos))
    return result
end

local function check_suffix(str, suffixes)
    local i
    for i = 1, #suffixes do
        if(string.sub(str,-string.len(suffixes[i]))==suffixes[i]) then
            return true, suffixes[i]
        end
    end
    return false, ''
end
 
local function get_payload(request)
    local tarr = split(request, "\r\n")
    local verb, resource, id, payload = '', '', '', ''
    local tmp
        
    -- gather data and prepare processing

    if(tarr[1]) then
        verb, tmp = tarr[1]:match("([^\ ]+)\ ([^\ ]+)")
    end

    if(tmp) then
        resource,payload = tmp:match("([^\?]+)?([^?]+)")
        if(resource == nil) then
            resource = tmp
        end
    end

    if(verb == 'POST' or verb == 'PUT') then
        if(payload) then
            payload = tarr[#tarr]..'&'..payload
        else
            payload = tarr[#tarr]
        end
    end

    if(resource) then
        tarr = split(resource, "/")
    end

    if(tarr) then
        if(#tarr == 3) then
            id = tarr[3]
            resource = tarr[2]
        elseif(#tarr == 2) then
            resource = tarr[2]
            id = nil
        else
            return '403 UNDEFINED only /resource or /resource/ID requests', 'text/plain'
        end
    end

    -- processing

    if(resource == '') then
        resource = 'index.html'
        local mime = 'text/html'
        return resource, mime, verb
    end

    if(verb == "PUT") then
        if(not payload) then
            return '403 PUT without payload', 'text/plain'
        end
        if(not id) then
            return "403 PUT only supports /resource/id", "text/plain"
        end
        if(not file_exists(resource..'.lua')) then
            return '403 RESOURCE not found', 'text/plain'
        end
        local rest = loadfile(resource .. '.lua')
        return rest(verb, id, cjson.encode(parseurl(payload)))
    end

    if(verb == "POST") then
        if(payload == '') then
            return '204 POST without payload', 'text/plain'
        end
        local norest, ext = check_suffix(resource, { ".cgi" })
        if(norest) then
            if(not file_exists(resource)) then
                return '404 RESOURCE not found', 'text/plain'
            end
            local cgi = loadfile(resource)
            return cgi(cjson.encode(parseurl(payload)))
        end
        if(not file_exists(resource..'.lua')) then
            return '404 RESOURCE not found', 'text/plain'
        end
        local rest = loadfile(resource .. '.lua')
        return rest(verb, id, cjson.encode(parseurl(payload)))
    end

    if(verb == "DELETE") then
        if(not file_exists(resource..'.lua')) then
            return '404 RESOURCE not found', 'text/plain'
        end
        local rest = loadfile(resource .. '.lua')
        if(payload ~= nil) then
            return rest(verb, id, cjson.encode(parseurl(payload)))
        else
            return rest(verb, id)
        end
    end
    
    if(verb == "GET") then
        local static, mime = check_suffix(resource, { ".html", ".css", ".png", ".js", ".json" })
        if(static) then
            if(mime == ".html") then mime = "text/html" end
            if(mime == ".css") then mime = "text/css" end
            if(mime == ".png") then mime = "image/png" end
            if(mime == ".js") then mime = "application/javascript" end
            if(mime == ".json") then mime = "application/json" end
            return resource, mime, verb
        end
        if(not file_exists(resource..'.lua')) then
            return '404 RESOURCE not found', 'text/plain'
        end

        local rest = loadfile(resource .. '.lua')
        if(payload ~= nil) then
            return rest(verb, id, cjson.encode(parseurl(payload)))
        else
            return rest(verb, id)
        end
    end
    payload = "501 UNDEFINED verb "..verb
    return payload, 'text/plain'
end

local request=...
if(request) then
    return get_payload(request)
end
