local function send_file(conn)
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

local function send_header(conn, status, mime, static)
    conn:send('HTTP/1.1 '..status..'\n')
    conn:send('Content-Type: '..mime..'\n')
    if(static) then
        conn:send('Expires: Wed, 31 Dec 2035 00:00:00 GMT\n')
    end
    conn:send("Connection: close\n\n")
end

local function answer_request(conn, payload, mime, verb)
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
print('forced close '..lastfile)
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

local conn, payload, mime, verb = ...
if(conn and payload and mime) then
    answer_request(conn, payload, mime, verb)
end
