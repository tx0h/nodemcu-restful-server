function open_file(filename, mode)
    if(g_fileFree) then
        g_fileFree = false
        lastfile = filename
        lastmode = mode

        if(file.open(filename, mode)) then
            return 0
        else
            g_fileFree = true
            lastfile = nil
            lastmode = nil
            return -1
        end
    else
        return -2
    end
end

function close_file()
    file.close()
    g_fileFree = true
    lastfile = nil
    lastmode = nil
end

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
    return true
    --[[
    if(not file.open(filename, 'r')) then
        close_file()
        return false
    end
    close_file()
    return true
    ]]
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


function send_file(conn)
    local chunk=file.read(1370)
    if chunk then
        conn:send(chunk)
    else
        close_file()
        tmr.stop(0)
        conn:on('sent', function () end);
        conn:close()
    end
    chunk = nil
    collectgarbage()
end

function send_header(conn, status, mime, static)
    conn:send('HTTP/1.1 '..status..'\n')
    conn:send('Content-Type: '..mime..'\n')
    if(static) then
        conn:send('Expires: Wed, 31 Dec 2035 00:00:00 GMT\n')
    end
    conn:send("Connection: close\n\n")
end

function answer_request(conn, request)
    local payload, mime, verb = get_payload(request)
    if(verb == 'GET' and mime ~= 'text/plain') then
	    local filestatus = open_file(payload, 'r')
        if(filestatus == 0) then
            send_header(conn, '200 OK', mime, true)
            tmr.alarm(0, 1000, 1,
                function()
                    if(not lastfile) then
                        file.close()
                        return
                    end
                    g_fileOpen = true
                    open_file(lastfile, lastmode)
                    pos = file.seek('cur')
                    if(not pos or old_pos == pos or old_pos == -23) then
                        old_pos = -23
print('forced close')
                        close_file()
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
        elseif(filestatus == -1) then
            close_file()
            send_header(conn, '403 File not found', 'text/plain')
            conn:send('403 File not found\r\n')
            conn:close()
        elseif(filestatus == -2) then
            conn:send('HTTP/1.1 302 Found\nLocation: /'..payload..'\n\n')
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
            end
        )
    end
)
