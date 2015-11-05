function urldecode(s)
    s = s:gsub('+', ' '):gsub('%%(%x%x)',
        function(h)
            return string.char(tonumber(h, 16))
        end)
    return s
end

function parseurl(s)
    local k, v
    local ans = {}
        for k,v in s:gmatch('([^&=?]-)=([^&=?]+)' ) do
        ans[ k ] = urldecode(v)
    end
    return ans
end

function split(str, delim)
    local result,pat,lastPos = {},"(.-)" .. delim .. "()", 1
    for part, pos in string.gfind(str, pat) do
        table.insert(result, part); lastPos = pos
    end
    table.insert(result, string.sub(str, lastPos))
    return result
end

function check_suffix(str, suffixes)
    local i
    for i = 1, #suffixes do
        if(string.sub(str,-string.len(suffixes[i]))==suffixes[i]) then
            return true, suffixes[i]
        end
    end
    return false, ''
end

function file_exists(filename)
    if(not file.open(filename, 'r')) then
        file.close()
        return false
    end
    file.close()
    return true
end
        
function get_payload(request)
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

    if(verb == 'POST') then
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
        --[[
        local index = loadfile('get_file.lua')
        return index('index.html')
        ]]
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
        --[[
        if(not id) then
            return "409 DELETE only supports /resource/id", "text/plain"
        end
        ]]
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

--[[
function get_file_size(filename)
    if(not file.open(filename, 'r')) then
        return(nil)
    end
    local size = file.seek("end")
    file.close()
    return(size)
end
]]


function send_file(conn)
    local chunk=file.read(768)
    if chunk then
        conn:send(chunk)
    else
        file.close()
        tmr.stop(0)
        g_fileFree = true
        conn:on('sent', function () end);
        conn:close()
    end
    chunk = nil
    collectgarbage()
end

function send_header(conn, status, mime)
    conn:send('HTTP/1.1 '..status..'\r\n')
    --conn:send('Date: Thu, 01 Jan 1970 00:00:00 GMT\r\n')
    --conn:send('Server: rest-server\r\n')
    --conn:send('Content-Length: '..len..'\r\n')
    conn:send('Content-Type: '..mime..'\r\n')
    conn:send("Connection: close\r\n\r\n")
end

function answer_request(conn, request)
    local payload, mime, verb = get_payload(request)
    --local len = payload:len()
    
    --[[
    if(verb == 'GET') then
        len = get_file_size(payload)
        if(not len) then
            payload = '404 RESOURCE not found'
            mime = 'text/plain'
            len = payload:len()
        end
    end
    ]]
    
    if(verb == 'GET' and mime ~= 'text/plain') then
        if(g_fileFree) then
            g_fileFree = false
            if(file.open(payload,'r')) then
                send_header(conn, '200 OK', mime)
                tmr.alarm(0, 500, 1,
                    function()
                        pos = file.seek('cur')
                        if(not pos or old_pos == pos or old_pos == -23) then
                            old_pos = -23
                            g_fileFree=true
                        else
                            old_pos = pos
                        end
                    end

                )
                conn:on('sent',
                    function ()
                        send_file(conn)
                    end
                )
            else
                g_fileFree = true
                send_header(conn, '403 File not found', 'text/plain')
                conn:send('403 File not found\r\n')
                conn:close()
            end
        else
            conn:send('HTTP/1.1 302 Found\r\nLocation: http://192.168.23.216/'..payload..'\r\n\r\n')   
            conn:close()
        end
    else
        if(payload:match('^[0-9][0-9][0-9]\ ')) then
            send_header(conn, payload, mime)
        else
            send_header(conn, '200 OK', mime)
        end
        conn:send(payload)
        conn:close()
    end
end

if(srv) then
    srv:close()
end
g_fileFree = true
srv=net.createServer(net.TCP, 33) 
srv:listen(80,
    function(conn)
        conn:on("receive",
            function(conn, payload)
                answer_request(conn, payload)
            end
        )
        conn:on("disconnection",
            function()
                collectgarbage()
                print('disconnection heap='..node.heap())
            end
        )
    end
)
