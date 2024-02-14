-- General Communication Protocol v1 (GCP)

local M = {}

component = require("component")
serialization = require("serialization")
event = require("event")
os = require("os")
math = require("math")

function M.GetRandomPort()
    x = math.random(49152, 65535)
    fx = math.floor(x)
    return fx
end
function M.GetHostName()
    file = io.open("/etc/hostname", "r")
    local data = file:read("*all")

    file:close()

    return data
end
function M.FileExists(path)
    local file = io.open(path, "r")
    if file then
        io.close(file)
        return true
    else
        return false
    end
end
gcp_src_port = M.GetRandomPort()

function M.gcp_cli_raw(gcp_input_data, gcp_dst_addr, gcp_dst_port, gcp_src_addr)
    local packet = {
        headers = {
            source_address = gcp_src_addr,
            source_port = gcp_src_port,
            source_hostname = M.GetHostName(),
            destination_address = gcp_dst_addr,
            destination_port = gcp_dst_port,
        },
        body = {
            meta_data = {
                data_type = "Raw", -- File, Raw, Command
            },
            data = gcp_input_data,
        },
    }

    serialized_packet = serialization.serialize(packet)

    component.modem.open(gcp_src_port)
    component.modem.send(gcp_dst_addr, gcp_dst_port, serialized_packet, gcp_src_port)

    _, _, _, _, _, response = event.pull(1, "modem") -- Receive for 1 seconds
    component.modem.close(gcp_src_port)

    return response
end
function M.gcp_cli_file(gcp_input_data, gcp_file_name, gcp_password, gcp_dst_addr, gcp_dst_port, gcp_src_addr)
    local packet = {
        headers = {
            source_address = gcp_src_addr,
            source_port = gcp_src_port,
            source_hostname = M.GetHostName(),
            destination_address = gcp_dst_addr,
            destination_port = gcp_dst_port,
        },
        body = {
            meta_data = {
                data_type = "File", -- File, Raw, Command
                file_name = gcp_file_name,
                password = gcp_password,
            },
            data = gcp_input_data,
        },
    }

    serialized_packet = serialization.serialize(packet)

    component.modem.open(gcp_src_port)
    component.modem.send(gcp_dst_addr, gcp_dst_port, serialized_packet, gcp_src_port)

    _, _, _, _, _, response = event.pull(1, "modem") -- Receive for 1 seconds
    component.modem.close(gcp_src_port)

    return response
end
function M.gcp_cli_command(gcp_input_data, gcp_password, gcp_dst_addr, gcp_dst_port, gcp_src_addr)
    local packet = {
        headers = {
            source_address = gcp_src_addr,
            source_port = gcp_src_port,
            source_hostname = M.GetHostName(),
            destination_address = gcp_dst_addr,
            destination_port = gcp_dst_port,
        },
        body = {
            meta_data = {
                data_type = "Command", -- File, Raw, Command
                password = gcp_password,
            },
            data = gcp_input_data,
        },
    }

    serialized_packet = serialization.serialize(packet)

    component.modem.open(gcp_src_port)
    component.modem.send(gcp_dst_addr, gcp_dst_port, serialized_packet, gcp_src_port)

    _, _, _, _, _, response = event.pull(1, "modem") -- Receive for 1 seconds
    component.modem.close(gcp_src_port)

    return response
end

function M.gcp_ser(gcp_server_port, gcp_server_password)
    log_file = io.open("/var/log/gcp.log", "a")
    component.modem.open(gcp_server_port)
    _, _, _, _, _, response = event.pull("modem")

    unserialized_response = serialization.unserialize(response)

    source_address = unserialized_response.headers.source_address
    source_port = unserialized_response.headers.source_port
    destination_port = unserialized_response.headers.destination_port
    data_type = unserialized_response.body.meta_data.data_type

    component.modem.close(gcp_server_port)

    if data_type == "File" then
        file_name = unserialized_response.body.meta_data.file_name
        data = unserialized_response.body.data
        password = unserialized_response.body.meta_data.password

        if password == gcp_server_password then
            file = io.open(file_name, "w")
            file:write(data)
            file:close()

            component.modem.send(source_address, source_port, "Done.")
            log_file:write(source_address .. ":" .. source_port .. " -> " .. "X-X-X-X:" .. destination_port .. " " .. "JSON: " .. response .. " " .. "Done." .. '\n\n')
            log_file:close()

            return "Done."
        else
            component.modem.send(source_address, source_port, "AccessDenied.")
            log_file:write(source_address .. ":" .. source_port .. " -> " .. "X-X-X-X:" .. destination_port .. " " .. "JSON: " .. response .. " " .. "AccessDenied." .. '\n\n')
            log_file:close()
            return "AccessDenied."
        end
    elseif data_type == "Command" then
        data = unserialized_response.body.data
        password = unserialized_response.body.meta_data.password

        if password == gcp_server_password then
            component.modem.send(source_address, source_port, "Done.")
            log_file:write(source_address .. ":" .. source_port .. " -> " .. "X-X-X-X:" .. destination_port .. " " .. "JSON: " .. response .. " " .. "Done." .. '\n\n')
            log_file:close()
            local Result = os.execute(data)
            return Result
        else
            component.modem.send(source_address, source_port, "AccessDenied.")
            log_file:write(source_address .. ":" .. source_port .. " -> " .. "X-X-X-X:" .. destination_port .. " " .. "JSON: " .. response .. " " .. "AccessDenied." .. '\n\n')
            log_file:close()
            return "AccessDenied."
        end
    elseif data_type == "Raw" then
        data = unserialized_response.body.data
        component.modem.send(source_address, source_port, "Done.")
        log_file:write(source_address .. ":" .. source_port .. " -> " .. "X-X-X-X:" .. destination_port .. " " .. "JSON: " .. response .. " " .. "Done." .. '\n\n')
        log_file:close()
        return unserialized_response
    end
end

return M
