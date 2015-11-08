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

if(srv) then
    srv:close()
end
g_fileFree = true
srv=net.createServer(net.TCP, 33)
srv:listen(80,
    function(conn)
        conn:on("receive",
            function(conn, request)
                local doit = loadfile('get_payload.lc')
                local payload, mime, verb = doit(request)
                doit = loadfile('answer_request.lc')
                doit(conn, payload, mime, verb)
            end
        )
        conn:on("disconnection",
            function()
                collectgarbage()
            end
        )
    end
)
