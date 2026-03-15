-- Nginx 配置生成器模块
-- 将 JSON 配置转换为 nginx 配置片段

local _M = {
    _VERSION = "1.0.0"
}

local storage = require "admin.storage"
local io_open = io.open

-- 缩进辅助函数
local function indent(level)
    return string.rep("    ", level or 1)
end

-- 转义 nginx 配置中的特殊字符
local function escape_nginx(str)
    if not str then return "" end
    return str:gsub("([;'\"%$\\])", "\\%1")
end

------------------------------------------------------------------------------
-- Upstream 配置生成
------------------------------------------------------------------------------
function _M.generate_upstream(item)
    if not item or not item.id then
        return nil, "upstream id is required"
    end

    local lines = {}
    table.insert(lines, "upstream " .. item.id .. " {")

    -- 负载均衡策略
    local balance = item.balance or "round_robin"
    if balance ~= "round_robin" then
        table.insert(lines, indent(1) .. balance .. ";")
    end

    -- 服务器列表
    for _, server in ipairs(item.servers or {}) do
        local server_line = indent(1) .. "server " .. server.host .. ":" .. server.port

        local params = {}
        if server.weight and server.weight ~= 1 then
            table.insert(params, "weight=" .. server.weight)
        end
        if server.backup then
            table.insert(params, "backup")
        end
        if server.down then
            table.insert(params, "down")
        end
        if server.max_fails then
            table.insert(params, "max_fails=" .. server.max_fails)
        end
        if server.fail_timeout then
            table.insert(params, "fail_timeout=" .. server.fail_timeout)
        end

        if #params > 0 then
            server_line = server_line .. " " .. table.concat(params, " ")
        end

        table.insert(lines, server_line .. ";")
    end

    -- keepalive
    if item.keepalive then
        table.insert(lines, indent(1) .. "keepalive " .. item.keepalive .. ";")
    end

    -- 健康检查 (需要 nginx-plus 或第三方模块)
    if item.health_check and item.health_check.enabled then
        local hc = item.health_check
        local hc_line = indent(1) .. "health_check"
        local hc_params = {}
        if hc.interval then
            table.insert(hc_params, "interval=" .. hc.interval)
        end
        if hc.fails then
            table.insert(hc_params, "fails=" .. hc.fails)
        end
        if hc.passes then
            table.insert(hc_params, "passes=" .. hc.passes)
        end
        if hc.uri then
            table.insert(hc_params, "uri=" .. hc.uri)
        end
        if #hc_params > 0 then
            hc_line = hc_line .. " " .. table.concat(hc_params, " ")
        end
        table.insert(lines, hc_line .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Location 配置生成
------------------------------------------------------------------------------
function _M.generate_location(item)
    if not item or not item.path then
        return nil, "location path is required"
    end

    local lines = {}
    local loc_type = item.location_type or ""
    local loc_header = "location " .. loc_type .. " " .. item.path .. " {"
    table.insert(lines, loc_header)

    -- 插件集成 (rewrite_by_lua / access_by_lua)
    if item.plugins and #item.plugins > 0 then
        for _, plugin in ipairs(item.plugins) do
            if plugin == "phone_range_router" then
                table.insert(lines, indent(1) .. "set $upstream default_backend;")
                table.insert(lines, "")
                table.insert(lines, indent(1) .. "rewrite_by_lua_block {")
                table.insert(lines, indent(2) .. 'require("phone_range_router.phone_range_router").prerouting()')
                table.insert(lines, indent(1) .. "}")
                table.insert(lines, "")
                table.insert(lines, indent(1) .. "access_by_lua_block {")
                table.insert(lines, indent(2) .. 'require("phone_range_router.phone_range_router").postrouting()')
                table.insert(lines, indent(1) .. "}")
                table.insert(lines, "")
            end
        end
    end

    -- 静态文件处理
    if item.root then
        table.insert(lines, indent(1) .. "root " .. item.root .. ";")
        if item.index then
            table.insert(lines, indent(1) .. "index " .. item.index .. ";")
        end
        if item.expires then
            table.insert(lines, indent(1) .. "expires " .. item.expires .. ";")
        end
        if item.cache_control then
            table.insert(lines, indent(1) .. 'add_header Cache-Control "' .. item.cache_control .. '";')
        end
    end

    -- 代理配置
    if item.proxy_pass then
        -- proxy_pass (可能使用变量)
        local proxy_target = item.proxy_pass
        if item.plugins and #item.plugins > 0 then
            -- 如果有插件，可能使用 $upstream 变量
            for _, plugin in ipairs(item.plugins) do
                if plugin == "phone_range_router" then
                    proxy_target = "http://$upstream"
                    break
                end
            end
        end
        table.insert(lines, indent(1) .. "proxy_pass " .. proxy_target .. ";")

        -- proxy_http_version
        if item.proxy_http_version then
            table.insert(lines, indent(1) .. "proxy_http_version " .. item.proxy_http_version .. ";")
        end

        -- proxy_set_header
        if item.proxy_set_header then
            for header, value in pairs(item.proxy_set_header) do
                table.insert(lines, indent(1) .. 'proxy_set_header ' .. header .. ' "' .. value .. '";')
            end
        end

        -- proxy_timeout
        if item.proxy_timeout then
            local timeout = item.proxy_timeout
            if timeout.connect then
                table.insert(lines, indent(1) .. "proxy_connect_timeout " .. timeout.connect .. ";")
            end
            if timeout.send then
                table.insert(lines, indent(1) .. "proxy_send_timeout " .. timeout.send .. ";")
            end
            if timeout.read then
                table.insert(lines, indent(1) .. "proxy_read_timeout " .. timeout.read .. ";")
            end
        end

        -- 其他常用代理设置
        table.insert(lines, indent(1) .. "proxy_redirect off;")
        table.insert(lines, indent(1) .. "proxy_buffering on;")
    end

    -- 限流配置
    if item.rate_limit and item.rate_limit.enabled then
        local rl = item.rate_limit
        table.insert(lines, indent(1) .. "limit_req zone=api_limit burst=" .. (rl.burst or 10) .. " nodelay;")
    end

    -- 自定义指令
    if item.directives then
        for _, directive in ipairs(item.directives) do
            table.insert(lines, indent(1) .. directive .. ";")
        end
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- HTTP Server 配置生成
------------------------------------------------------------------------------
function _M.generate_http_server(item, locations)
    if not item or not item.listen then
        return nil, "server listen is required"
    end

    local lines = {}
    table.insert(lines, "server {")

    -- listen
    local listens = item.listen
    if type(listens) ~= "table" then
        listens = { { port = listens } }
    end

    for _, l in ipairs(listens) do
        local listen_line = indent(1) .. "listen " .. (l.port or 80)
        if l.ssl then
            listen_line = listen_line .. " ssl"
        end
        if l.http2 then
            listen_line = listen_line .. " http2"
        end
        table.insert(lines, listen_line .. ";")
    end

    -- server_name
    if item.server_name then
        table.insert(lines, indent(1) .. "server_name " .. item.server_name .. ";")
    end

    -- SSL 配置
    for _, l in ipairs(listens) do
        if l.ssl then
            if l.certificate then
                table.insert(lines, indent(1) .. "ssl_certificate " .. l.certificate .. ";")
            end
            if l.certificate_key then
                table.insert(lines, indent(1) .. "ssl_certificate_key " .. l.certificate_key .. ";")
            end
            break
        end
    end

    -- root
    if item.root then
        table.insert(lines, indent(1) .. "root " .. item.root .. ";")
    end

    -- index
    if item.index then
        table.insert(lines, indent(1) .. "index " .. item.index .. ";")
    end

    -- 日志
    if item.access_log then
        table.insert(lines, indent(1) .. "access_log " .. item.access_log .. ";")
    end
    if item.error_log then
        table.insert(lines, indent(1) .. "error_log " .. item.error_log .. ";")
    end

    -- locations
    if locations then
        table.insert(lines, "")
        for _, loc in ipairs(locations) do
            local loc_config, err = _M.generate_location(loc)
            if loc_config then
                -- 添加缩进
                for line in loc_config:gmatch("[^\n]+") do
                    table.insert(lines, indent(1) .. line)
                end
            end
        end
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Stream Server 配置生成
------------------------------------------------------------------------------
function _M.generate_stream_server(item, upstreams)
    if not item or not item.listen then
        return nil, "stream listen is required"
    end

    local lines = {}
    table.insert(lines, "server {")

    -- listen
    local listen_str = item.listen
    if type(listen_str) == "number" then
        listen_str = tostring(listen_str)
    end
    table.insert(lines, indent(1) .. "listen " .. listen_str .. ";")

    -- proxy_pass
    if item.proxy_pass then
        local proxy_target = item.proxy_pass
        -- 检查是否是 upstream 引用
        if upstreams and upstreams[proxy_target] then
            proxy_target = proxy_target -- upstream 名称
        end
        table.insert(lines, indent(1) .. "proxy_pass " .. proxy_target .. ";")
    end

    -- timeout
    if item.timeout then
        local timeout = item.timeout
        if timeout.connect then
            table.insert(lines, indent(1) .. "proxy_connect_timeout " .. timeout.connect .. ";")
        end
        if timeout.read then
            table.insert(lines, indent(1) .. "proxy_timeout " .. timeout.read .. ";")
        end
        if timeout.send then
            table.insert(lines, indent(1) .. "proxy_timeout " .. timeout.send .. ";")
        end
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
        upstreams = {},
        http_servers = {},
        stream_servers = {},
        locations = {}
    }

    -- 加载所有配置
    local upstream_config = storage.load("upstream")
    local http_config = storage.load("http")
    local stream_config = storage.load("stream")
    local location_config = storage.load("location")

    -- 生成 upstream 配置
    if upstream_config and upstream_config.items then
        for _, item in ipairs(upstream_config.items) do
            local conf, err = _M.generate_upstream(item)
            if conf then
                table.insert(result.upstreams, conf)
                result.upstreams[item.id] = item  -- 保存引用
            else
                ngx.log(ngx.WARN, "Failed to generate upstream ", item.id, ": ", err)
            end
        end
    end

    -- 生成 location 配置
    local locations = {}
    if location_config and location_config.items then
        for _, item in ipairs(location_config.items) do
            local conf, err = _M.generate_location(item)
            if conf then
                table.insert(result.locations, conf)
                table.insert(locations, item)
            else
                ngx.log(ngx.WARN, "Failed to generate location ", item.path, ": ", err)
            end
        end
    end

    -- 生成 http server 配置
    if http_config and http_config.items then
        for _, item in ipairs(http_config.items) do
            local conf, err = _M.generate_http_server(item, locations)
            if conf then
                table.insert(result.http_servers, conf)
            else
                ngx.log(ngx.WARN, "Failed to generate http server: ", err)
            end
        end
    end

    -- 生成 stream server 配置
    if stream_config and stream_config.items then
        for _, item in ipairs(stream_config.items) do
            local conf, err = _M.generate_stream_server(item, result.upstreams)
            if conf then
                table.insert(result.stream_servers, conf)
            else
                ngx.log(ngx.WARN, "Failed to generate stream server: ", err)
            end
        end
    end

    return result
end

------------------------------------------------------------------------------
-- 生成完整的 nginx.conf
------------------------------------------------------------------------------
function _M.generate_nginx_conf(template_path)
    local configs = _M.generate_all()

    local parts = {}

    -- upstream 配置
    if #configs.upstreams > 0 then
        table.insert(parts, "# Upstreams")
        for _, conf in ipairs(configs.upstreams) do
            table.insert(parts, conf)
        end
    end

    -- HTTP servers
    if #configs.http_servers > 0 then
        table.insert(parts, "# HTTP Servers")
        for _, conf in ipairs(configs.http_servers) do
            table.insert(parts, conf)
        end
    end

    return table.concat(parts, "\n")
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