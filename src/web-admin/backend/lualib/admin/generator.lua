-- Nginx 配置生成器模块
-- 将 JSON 配置转换为 nginx 配置片段
-- 支持新的资源模型: servers, server-groups, routes, listeners-http, listeners-tcp

local _M = {
    _VERSION = "2.0.0"
}

local storage = require "admin.storage"
local io_open = io.open

------------------------------------------------------------------------------
-- 工具函数
------------------------------------------------------------------------------

-- 缩进辅助函数
local function indent(level)
    return string.rep("    ", level or 1)
end

-- 获取服务器信息
local function get_server_info(server_id, servers_map)
    return servers_map[server_id]
end

-- 解析自定义指令
local function parse_custom_directives(directives_str)
    if not directives_str or directives_str == "" then
        return {}
    end

    local directives = {}
    for line in directives_str:gmatch("[^\n]+") do
        line = line:gsub("^%s+", ""):gsub("%s+$", "")
        if line ~= "" then
            table.insert(directives, line)
        end
    end
    return directives
end

------------------------------------------------------------------------------
-- Upstream 配置生成 (基于 server-groups 和 servers)
------------------------------------------------------------------------------

function _M.generate_upstream(group, servers_map)
    if not group or not group.id then
        return nil, "group id is required"
    end

    local lines = { "upstream " .. group.id .. " {" }

    -- 负载均衡策略
    local balance = group.balance or "round_robin"
    if balance ~= "round_robin" then
        table.insert(lines, indent(1) .. balance .. ";")
    end

    -- 引用的服务器
    for _, server_id in ipairs(group.server_refs or {}) do
        local server = get_server_info(server_id, servers_map)
        if server then
            local server_line = indent(1) .. "server " .. server.host .. ":" .. server.port
            if server.weight and server.weight ~= 1 then
                server_line = server_line .. " weight=" .. server.weight
            end
            server_line = server_line .. ";"
            table.insert(lines, server_line)
        end
    end

    -- 自定义指令
    local directives = parse_custom_directives(group.custom_directives)
    for _, directive in ipairs(directives) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Location 配置生成 (基于 routes)
------------------------------------------------------------------------------

function _M.generate_location(route, server_groups_map)
    if not route or not route.path then
        return nil, "route path is required"
    end

    local lines = {}
    table.insert(lines, "location " .. route.path .. " {")

    -- 检查是否配置了有效的后端服务器组
    local has_proxy = false
    if route.server_group_ref and route.server_group_ref ~= "" then
        local group = server_groups_map[route.server_group_ref]
        if group then
            has_proxy = true
            table.insert(lines, indent(1) .. "proxy_pass http://" .. route.server_group_ref .. ";")
            -- 标准代理设置
            table.insert(lines, indent(1) .. "proxy_http_version 1.1;")
            table.insert(lines, indent(1) .. 'proxy_set_header Host $host;')
            table.insert(lines, indent(1) .. 'proxy_set_header X-Real-IP $remote_addr;')
            table.insert(lines, indent(1) .. 'proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;')
            table.insert(lines, indent(1) .. "proxy_redirect off;")
        end
    end

    -- 自定义指令
    local directives = parse_custom_directives(route.custom_directives)
    for _, directive in ipairs(directives) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- HTTP Server 配置生成 (基于 listeners-http)
------------------------------------------------------------------------------

function _M.generate_http_server(listener, routes_map, server_groups_map)
    if not listener or not listener.id then
        return nil, "listener id is required"
    end

    local lines = { "server {" }

    -- listen 指令
    local listens = listener.listen or {{ port = 80, ssl = false }}
    if type(listens) ~= "table" then
        listens = { { port = listens, ssl = false } }
    end

    for _, l in ipairs(listens) do
        local listen_line = indent(1) .. "listen " .. (l.port or 80)
        if l.ssl then listen_line = listen_line .. " ssl" end
        table.insert(lines, listen_line .. ";")
    end

    -- server_name (只在有值时生成)
    if listener.server_name and listener.server_name ~= "" then
        table.insert(lines, indent(1) .. "server_name " .. listener.server_name .. ";")
    end

    -- 引用的路由规则
    for _, route_id in ipairs(listener.route_refs or {}) do
        local route = routes_map[route_id]
        if route then
            local loc_config = _M.generate_location(route, server_groups_map)
            if loc_config then
                for line in loc_config:gmatch("[^\n]+") do
                    table.insert(lines, indent(1) .. line)
                end
            end
        end
    end

    -- 自定义指令
    local directives = parse_custom_directives(listener.custom_directives)
    for _, directive in ipairs(directives) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Stream Server 配置生成 (基于 listeners-tcp)
------------------------------------------------------------------------------

function _M.generate_stream_server(listener)
    if not listener or not listener.id then
        return nil, "listener id is required"
    end

    local lines = { "server {" }

    -- listen
    local listen_str = listener.listen
    if listener.protocol == "udp" then
        listen_str = listen_str .. " udp"
    end
    table.insert(lines, indent(1) .. "listen " .. listen_str .. ";")

    -- 代理到后端服务器组
    if listener.server_group_ref then
        table.insert(lines, indent(1) .. "proxy_pass " .. listener.server_group_ref .. ";")
    end

    -- 自定义指令
    local directives = parse_custom_directives(listener.custom_directives)
    for _, directive in ipairs(directives) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- 生成 Stream Upstream (用于 TCP/UDP 代理)
------------------------------------------------------------------------------

function _M.generate_stream_upstream(group, servers_map)
    if not group or not group.id then
        return nil, "group id is required"
    end

    local lines = { "upstream " .. group.id .. " {" }

    -- 负载均衡策略
    local balance = group.balance or "round_robin"
    if balance ~= "round_robin" then
        table.insert(lines, indent(1) .. balance .. ";")
    end

    -- 引用的服务器
    for _, server_id in ipairs(group.server_refs or {}) do
        local server = get_server_info(server_id, servers_map)
        if server then
            local server_line = indent(1) .. "server " .. server.host .. ":" .. server.port
            if server.weight and server.weight ~= 1 then
                server_line = server_line .. " weight=" .. server.weight
            end
            server_line = server_line .. ";"
            table.insert(lines, server_line)
        end
    end

    -- 自定义指令
    local directives = parse_custom_directives(group.custom_directives)
    for _, directive in ipairs(directives) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- 生成所有配置
------------------------------------------------------------------------------

function _M.generate_all()
    local result = {
        upstream_configs = {},
        stream_upstream_configs = {},
        http_servers = {},
        stream_servers = {}
    }

    -- 加载所有资源
    local servers_config = storage.load("servers")
    local server_groups_config = storage.load("server-groups")
    local routes_config = storage.load("routes")
    local http_listeners_config = storage.load("listeners-http")
    local tcp_listeners_config = storage.load("listeners-tcp")

    -- 构建映射表
    local servers_map = {}
    if servers_config and servers_config.items then
        for _, item in ipairs(servers_config.items) do
            servers_map[item.id] = item
        end
    end

    local server_groups_map = {}
    local tcp_server_groups = {}  -- 被 TCP 监听器引用的服务器组
    if server_groups_config and server_groups_config.items then
        for _, item in ipairs(server_groups_config.items) do
            server_groups_map[item.id] = item
        end
    end

    local routes_map = {}
    if routes_config and routes_config.items then
        for _, item in ipairs(routes_config.items) do
            routes_map[item.id] = item
        end
    end

    -- 收集被 TCP 监听器引用的服务器组
    if tcp_listeners_config and tcp_listeners_config.items then
        for _, listener in ipairs(tcp_listeners_config.items) do
            if listener.server_group_ref then
                tcp_server_groups[listener.server_group_ref] = true
            end
        end
    end

    -- 生成 HTTP upstream 配置 (被路由规则引用的服务器组)
    local http_upstream_ids = {}
    if routes_config and routes_config.items then
        for _, route in ipairs(routes_config.items) do
            if route.server_group_ref and not http_upstream_ids[route.server_group_ref] then
                local group = server_groups_map[route.server_group_ref]
                if group then
                    local conf = _M.generate_upstream(group, servers_map)
                    if conf then
                        table.insert(result.upstream_configs, conf)
                    end
                end
                http_upstream_ids[route.server_group_ref] = true
            end
        end
    end

    -- 生成 Stream upstream 配置 (被 TCP 监听器引用的服务器组)
    for group_id, _ in pairs(tcp_server_groups) do
        local group = server_groups_map[group_id]
        if group then
            local conf = _M.generate_stream_upstream(group, servers_map)
            if conf then
                table.insert(result.stream_upstream_configs, conf)
            end
        end
    end

    -- 生成 HTTP Server 配置
    if http_listeners_config and http_listeners_config.items then
        for _, listener in ipairs(http_listeners_config.items) do
            local conf = _M.generate_http_server(listener, routes_map, server_groups_map)
            if conf then
                table.insert(result.http_servers, conf)
            end
        end
    end

    -- 生成 Stream Server 配置
    if tcp_listeners_config and tcp_listeners_config.items then
        for _, listener in ipairs(tcp_listeners_config.items) do
            local conf = _M.generate_stream_server(listener)
            if conf then
                table.insert(result.stream_servers, conf)
            end
        end
    end

    return result
end

------------------------------------------------------------------------------
-- 写入配置文件
------------------------------------------------------------------------------

function _M.write_config(filepath, content)
    local file, err = io_open(filepath, "w")
    if not file then
        return nil, "Failed to open file: " .. (err or "unknown")
    end

    file:write(content)
    file:close()

    return true
end

return _M