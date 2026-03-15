-- Nginx 配置生成器模块
-- 将 JSON 配置转换为 nginx 配置片段

local _M = {
    _VERSION = "1.0.0"
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

-- 转义 nginx 配置中的特殊字符
local function escape_nginx(str)
    if not str then return "" end
    return str:gsub("([;'\"%$\\])", "\\%1")
end

-- 构建 server 参数字符串
local function build_server_params(server)
    local params = {}
    local param_keys = { "weight", "max_fails", "fail_timeout" }

    for _, key in ipairs(param_keys) do
        if server[key] and (key ~= "weight" or server[key] ~= 1) then
            table.insert(params, key .. "=" .. server[key])
        end
    end

    if server.backup then table.insert(params, "backup") end
    if server.down then table.insert(params, "down") end

    return #params > 0 and " " .. table.concat(params, " ") or ""
end

------------------------------------------------------------------------------
-- Upstream 配置生成
------------------------------------------------------------------------------

function _M.generate_upstream(item)
    if not item or not item.id then
        return nil, "upstream id is required"
    end

    local lines = { "upstream " .. item.id .. " {" }

    -- 负载均衡策略
    local balance = item.balance or "round_robin"
    if balance ~= "round_robin" then
        table.insert(lines, indent(1) .. balance .. ";")
    end

    -- 服务器列表
    for _, server in ipairs(item.servers or {}) do
        local server_line = indent(1) .. "server " .. server.host .. ":" .. server.port
        server_line = server_line .. build_server_params(server) .. ";"
        table.insert(lines, server_line)
    end

    -- keepalive
    if item.keepalive then
        table.insert(lines, indent(1) .. "keepalive " .. item.keepalive .. ";")
    end

    -- 健康检查 (标准 OpenResty 不支持 health_check 指令，改为注释提示)
    if item.health_check and item.health_check.enabled then
        local hc = item.health_check
        table.insert(lines, indent(1) .. "# 健康检查配置 (需要 nginx-plus 或第三方模块)")
        table.insert(lines, indent(1) .. "# health_check interval=" .. (hc.interval or "5s") ..
            " fails=" .. (hc.fails or 3) .. " passes=" .. (hc.passes or 2) ..
            " uri=" .. (hc.uri or "/health") .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- Location 配置生成
------------------------------------------------------------------------------

-- 生成插件配置
local function generate_plugins_config(plugins)
    local lines = {}

    for _, plugin in ipairs(plugins or {}) do
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

    return lines
end

-- 生成静态文件配置
local function generate_static_config(item)
    local lines = {}

    if not item.root then return lines end

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

    return lines
end

-- 生成代理配置
local function generate_proxy_config(item, has_plugins)
    local lines = {}

    if not item.proxy_pass then return lines end

    -- 确定 proxy_pass 目标
    local proxy_target = item.proxy_pass
    if has_plugins then
        for _, plugin in ipairs(item.plugins or {}) do
            if plugin == "phone_range_router" then
                proxy_target = "http://$upstream"
                break
            end
        end
    end
    table.insert(lines, indent(1) .. "proxy_pass " .. proxy_target .. ";")

    -- HTTP 版本
    if item.proxy_http_version then
        table.insert(lines, indent(1) .. "proxy_http_version " .. item.proxy_http_version .. ";")
    end

    -- Headers
    if item.proxy_set_header then
        for header, value in pairs(item.proxy_set_header) do
            table.insert(lines, indent(1) .. 'proxy_set_header ' .. header .. ' "' .. value .. '";')
        end
    end

    -- Timeouts
    local timeout_keys = { "connect", "send", "read" }
    for _, key in ipairs(timeout_keys) do
        if item.proxy_timeout and item.proxy_timeout[key] then
            table.insert(lines, indent(1) .. "proxy_" .. key .. "_timeout " .. item.proxy_timeout[key] .. ";")
        end
    end

    -- 默认代理设置
    table.insert(lines, indent(1) .. "proxy_redirect off;")
    table.insert(lines, indent(1) .. "proxy_buffering on;")

    return lines
end

function _M.generate_location(item)
    if not item or not item.path then
        return nil, "location path is required"
    end

    local lines = {}
    local loc_type = item.location_type or ""
    table.insert(lines, "location " .. loc_type .. " " .. item.path .. " {")

    -- 插件配置
    local plugin_lines = generate_plugins_config(item.plugins)
    for _, line in ipairs(plugin_lines) do
        table.insert(lines, line)
    end

    -- 静态文件配置
    local static_lines = generate_static_config(item)
    for _, line in ipairs(static_lines) do
        table.insert(lines, line)
    end

    -- 代理配置
    local proxy_lines = generate_proxy_config(item, item.plugins and #item.plugins > 0)
    for _, line in ipairs(proxy_lines) do
        table.insert(lines, line)
    end

    -- 限流配置
    if item.rate_limit and item.rate_limit.enabled then
        local rl = item.rate_limit
        table.insert(lines, indent(1) .. "limit_req zone=api_limit burst=" .. (rl.burst or 10) .. " nodelay;")
    end

    -- 自定义指令
    for _, directive in ipairs(item.directives or {}) do
        table.insert(lines, indent(1) .. directive .. ";")
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- HTTP Server 配置生成
------------------------------------------------------------------------------

-- 生成 listen 指令
local function generate_listen_directives(listens)
    local lines = {}

    if type(listens) ~= "table" then
        listens = { { port = listens } }
    end

    for _, l in ipairs(listens) do
        local listen_line = indent(1) .. "listen " .. (l.port or 80)
        if l.ssl then listen_line = listen_line .. " ssl" end
        if l.http2 then listen_line = listen_line .. " http2" end
        table.insert(lines, listen_line .. ";")
    end

    return lines, listens
end

-- 生成 SSL 配置
local function generate_ssl_config(listens)
    local lines = {}

    for _, l in ipairs(listens or {}) do
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

    return lines
end

-- 生成 location 块
local function generate_location_blocks(locations)
    local lines = {}

    if not locations then return lines end

    table.insert(lines, "")
    for _, loc in ipairs(locations) do
        local loc_config = _M.generate_location(loc)
        if loc_config then
            for line in loc_config:gmatch("[^\n]+") do
                table.insert(lines, indent(1) .. line)
            end
        end
    end

    return lines
end

function _M.generate_http_server(item, locations)
    if not item or not item.listen then
        return nil, "server listen is required"
    end

    local lines = { "server {" }

    -- listen 指令
    local listen_lines, listens = generate_listen_directives(item.listen)
    for _, line in ipairs(listen_lines) do
        table.insert(lines, line)
    end

    -- server_name
    if item.server_name then
        table.insert(lines, indent(1) .. "server_name " .. item.server_name .. ";")
    end

    -- SSL 配置
    local ssl_lines = generate_ssl_config(listens)
    for _, line in ipairs(ssl_lines) do
        table.insert(lines, line)
    end

    -- root 和 index
    if item.root then table.insert(lines, indent(1) .. "root " .. item.root .. ";") end
    if item.index then table.insert(lines, indent(1) .. "index " .. item.index .. ";") end

    -- 日志
    if item.access_log then table.insert(lines, indent(1) .. "access_log " .. item.access_log .. ";") end
    if item.error_log then table.insert(lines, indent(1) .. "error_log " .. item.error_log .. ";") end

    -- locations
    local loc_lines = generate_location_blocks(locations)
    for _, line in ipairs(loc_lines) do
        table.insert(lines, line)
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

    local lines = { "server {" }

    -- listen
    local listen_str = type(item.listen) == "number" and tostring(item.listen) or item.listen
    table.insert(lines, indent(1) .. "listen " .. listen_str .. ";")

    -- proxy_pass
    if item.proxy_pass then
        table.insert(lines, indent(1) .. "proxy_pass " .. item.proxy_pass .. ";")
    end

    -- timeout
    if item.timeout then
        if item.timeout.connect then
            table.insert(lines, indent(1) .. "proxy_connect_timeout " .. item.timeout.connect .. ";")
        end
        local timeout_value = item.timeout.read or item.timeout.send
        if timeout_value then
            table.insert(lines, indent(1) .. "proxy_timeout " .. timeout_value .. ";")
        end
    end

    table.insert(lines, "}")
    table.insert(lines, "")

    return table.concat(lines, "\n")
end

------------------------------------------------------------------------------
-- 生成所有配置
------------------------------------------------------------------------------

-- 通用的配置生成辅助函数
local function generate_configs(domain, generator, result_key, result, ...)
    local config = storage.load(domain)
    if not config or not config.items then return end

    for _, item in ipairs(config.items) do
        local conf = generator(item, ...)
        if conf then
            table.insert(result[result_key], conf)
        else
            ngx.log(ngx.WARN, "Failed to generate " .. domain .. ": ", item.id or item.path or "unknown")
        end
    end
end

function _M.generate_all()
    local result = {
        upstream_configs = {},
        upstream_refs = {},
        http_servers = {},
        stream_servers = {},
        locations = {}
    }

    -- 生成 upstream 配置
    local upstream_config = storage.load("upstream")
    if upstream_config and upstream_config.items then
        for _, item in ipairs(upstream_config.items) do
            local conf = _M.generate_upstream(item)
            if conf then
                table.insert(result.upstream_configs, conf)
                result.upstream_refs[item.id] = item
            end
        end
    end

    -- 生成 location 配置
    local location_config = storage.load("location")
    local locations = {}
    if location_config and location_config.items then
        for _, item in ipairs(location_config.items) do
            local conf = _M.generate_location(item)
            if conf then
                table.insert(result.locations, conf)
                table.insert(locations, item)
            end
        end
    end

    -- 生成 http server 配置
    local http_config = storage.load("http")
    if http_config and http_config.items then
        for _, item in ipairs(http_config.items) do
            local conf = _M.generate_http_server(item, locations)
            if conf then table.insert(result.http_servers, conf) end
        end
    end

    -- 生成 stream server 配置
    local stream_config = storage.load("stream")
    if stream_config and stream_config.items then
        for _, item in ipairs(stream_config.items) do
            local conf = _M.generate_stream_server(item, result.upstream_refs)
            if conf then table.insert(result.stream_servers, conf) end
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

    local sections = {
        { title = "# Upstreams", configs = configs.upstream_configs },
        { title = "# HTTP Servers", configs = configs.http_servers }
    }

    for _, section in ipairs(sections) do
        if #section.configs > 0 then
            table.insert(parts, section.title)
            for _, conf in ipairs(section.configs) do
                table.insert(parts, conf)
            end
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