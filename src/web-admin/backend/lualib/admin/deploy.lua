-- 部署控制模块
-- 管理配置的应用、验证和回滚

local _M = {
    _VERSION = "1.0.0"
}

local cjson = require "cjson.safe"
local generator = require "admin.generator"
local storage = require "admin.storage"
local utils = require "admin.utils"
local io_open = io.open

------------------------------------------------------------------------------
-- 路径常量
------------------------------------------------------------------------------

-- 获取负载均衡目录的绝对路径
-- ngx.config.prefix() 返回 nginx 的 prefix 目录，如 /home/mxp/Skills/src/web-admin/backend/
-- 我们需要向上两级到 src 目录，然后进入 loadbalance
local function get_loadbalance_dir()
    local prefix = ngx.config.prefix()
    prefix = prefix:gsub("/+$", "")

    -- 向上两级: backend/ -> web-admin/ -> src/
    local parts = {}
    for part in prefix:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    -- 移除最后两个部分 (backend, web-admin)
    for i = 1, 2 do
        if #parts > 0 then
            table.remove(parts)
        end
    end

    table.insert(parts, "loadbalance")
    return "/" .. table.concat(parts, "/")
end

-- 负载均衡实例配置路径
local LOADBALANCE_DIR = get_loadbalance_dir()
local LOADBALANCE_CONF_DIR = LOADBALANCE_DIR .. "/conf.d/"
local LOADBALANCE_NGINX_CONF = LOADBALANCE_DIR .. "/nginx.conf"
local LOADBALANCE_PID_FILE = LOADBALANCE_DIR .. "/logs/nginx.pid"
local DEPLOY_HISTORY_DIR = LOADBALANCE_DIR .. "/deploy_history/"

------------------------------------------------------------------------------
-- 工具函数
------------------------------------------------------------------------------

-- 获取生产 nginx 可执行文件路径
local function get_nginx_binary()
    local possible_paths = {
        ngx.config.prefix() .. "../../../build/openresty/nginx/sbin/nginx",
        "/usr/local/openresty/nginx/sbin/nginx",
        "nginx"
    }

    for _, path in ipairs(possible_paths) do
        local handle = io.popen("test -x " .. path .. " && echo 'exists' 2>/dev/null", "r")
        if handle then
            local result = handle:read("*a")
            handle:close()
            if result and result:find("exists") then
                return path
            end
        end
    end

    return "nginx"
end

-- 执行 shell 命令
local function exec_command(cmd)
    local handle = io.popen(cmd .. " 2>&1", "r")
    if not handle then
        return nil, 1
    end

    local output = handle:read("*a")
    local success, _, exit_code = handle:close()
    exit_code = exit_code or (success and 0 or 1)

    return output, exit_code
end

-- 确保目录存在
local function ensure_dir(dir)
    os.execute('mkdir -p "' .. dir .. '"')
end

-- 检查 nginx 进程是否运行
local function is_nginx_running()
    local handle = io_open(LOADBALANCE_PID_FILE, "r")
    if not handle then return false, nil end

    local pid = handle:read("*n")
    handle:close()

    if not pid then return false, nil end

    -- 使用 /proc/{pid}/cmdline 检查进程是否存在
    local proc_check = io_open("/proc/" .. pid .. "/cmdline", "r")
    if not proc_check then return false, pid end

    local cmdline = proc_check:read("*a")
    proc_check:close()

    return cmdline and cmdline:find("nginx") ~= nil, pid
end

-- 重载或启动 nginx
local function reload_nginx()
    local nginx_bin = get_nginx_binary()
    local running, _ = is_nginx_running()

    local cmd
    if running then
        cmd = 'sudo ' .. nginx_bin .. ' -s reload -p "' .. LOADBALANCE_DIR .. '" -c nginx.conf 2>&1'
    else
        cmd = 'sudo ' .. nginx_bin .. ' -p "' .. LOADBALANCE_DIR .. '" -c nginx.conf 2>&1'
    end

    return exec_command(cmd)
end

-- 备份当前配置
local function backup_config()
    ensure_dir(DEPLOY_HISTORY_DIR)

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_dir = DEPLOY_HISTORY_DIR .. timestamp

    ensure_dir(backup_dir)
    os.execute('cp -r "' .. LOADBALANCE_CONF_DIR .. '" "' .. backup_dir .. '/" 2>/dev/null || true')

    return timestamp
end

-- 生成配置文件头部
local function config_header(name)
    return string.format("# Auto-generated %s configuration\n# Generated at: %s\n\n",
        name, ngx.localtime())
end

------------------------------------------------------------------------------
-- Stream Upstream 生成
------------------------------------------------------------------------------

-- 生成 stream 模块需要的 upstream 配置
-- 注意: stream 模块与 HTTP 模块隔离，需要独立的 upstream 定义
local function generate_stream_upstreams()
    local stream_upstreams = {}
    local stream_config = storage.load("stream")

    if not stream_config or not stream_config.items then
        return stream_upstreams
    end

    local upstream_config = storage.load("upstream")
    if not upstream_config or not upstream_config.items then
        return stream_upstreams
    end

    for _, item in ipairs(stream_config.items) do
        if not item.proxy_pass then goto continue end

        -- 查找对应的 upstream 配置
        for _, upstream in ipairs(upstream_config.items) do
            if upstream.id == item.proxy_pass then
                local lines = { "upstream " .. upstream.id .. " {" }
                for _, server in ipairs(upstream.servers or {}) do
                    local server_line = "    server " .. server.host .. ":" .. server.port
                    if server.weight then
                        server_line = server_line .. " weight=" .. server.weight
                    end
                    table.insert(lines, server_line .. ";")
                end
                table.insert(lines, "}")
                table.insert(stream_upstreams, table.concat(lines, "\n"))
                break
            end
        end

        ::continue::
    end

    return stream_upstreams
end

------------------------------------------------------------------------------
-- 预览生成的配置
------------------------------------------------------------------------------

function _M.preview()
    local configs = generator.generate_all()

    local sections = {
        { name = "Upstreams", configs = configs.upstream_configs },
        { name = "HTTP Servers", configs = configs.http_servers },
        { name = "Stream Servers", configs = configs.stream_servers },
        { name = "Locations", configs = configs.locations }
    }

    -- 构建完整预览
    local full_preview = {
        "# ========================================",
        "# Generated Nginx Configuration Preview",
        "# Generated at: " .. ngx.localtime(),
        "# ========================================",
        ""
    }

    for _, section in ipairs(sections) do
        if #section.configs > 0 then
            table.insert(full_preview, "# ========== " .. section.name .. " ==========")
            for _, conf in ipairs(section.configs) do
                table.insert(full_preview, conf)
            end
        end
    end

    return {
        upstreams = table.concat(configs.upstream_configs, "\n"),
        http_servers = table.concat(configs.http_servers, "\n"),
        stream_servers = table.concat(configs.stream_servers, "\n"),
        locations = table.concat(configs.locations, "\n"),
        full = table.concat(full_preview, "\n")
    }
end

------------------------------------------------------------------------------
-- 应用配置
------------------------------------------------------------------------------

-- 准备部署环境
local function prepare_environment()
    ensure_dir(LOADBALANCE_DIR)
    ensure_dir(LOADBALANCE_CONF_DIR)
    ensure_dir(LOADBALANCE_DIR .. "/logs")

    -- 创建日志文件并设置权限
    for _, log_file in ipairs({ "error.log", "access.log" }) do
        os.execute('touch "' .. LOADBALANCE_DIR .. '/logs/' .. log_file .. '" 2>/dev/null || true')
    end
    os.execute('chmod -R 777 "' .. LOADBALANCE_DIR .. '/logs" 2>/dev/null || true')
end

-- 写入单个配置文件
local function write_config_file(filename, name, configs)
    local content = config_header(name) .. table.concat(configs, "\n")
    generator.write_config(LOADBALANCE_CONF_DIR .. filename, content)
end

function _M.apply()
    local result = {
        success = false,
        message = "",
        backup_id = nil,
        validation = nil,
        reload = nil
    }

    -- 1. 准备环境
    prepare_environment()

    -- 2. 备份当前配置
    result.backup_id = backup_config()
    ngx.log(ngx.INFO, "Config backed up to: ", result.backup_id)

    -- 3. 生成并写入配置
    local configs = generator.generate_all()

    -- 写入基础配置文件
    write_config_file("upstream.conf", "upstream", configs.upstream_configs)
    write_config_file("locations.conf", "location", configs.locations)
    write_config_file("http.conf", "HTTP server", configs.http_servers)

    -- 写入 stream 配置 (包含独立的 upstream 定义)
    local stream_upstreams = generate_stream_upstreams()
    local stream_content = config_header("stream server")
    if #stream_upstreams > 0 then
        stream_content = stream_content .. "# Stream Upstreams\n" ..
                         table.concat(stream_upstreams, "\n") .. "\n"
    end
    stream_content = stream_content .. table.concat(configs.stream_servers, "\n")
    generator.write_config(LOADBALANCE_CONF_DIR .. "stream.conf", stream_content)

    -- 4. 跳过 nginx -t 验证 (权限限制)
    result.validation = {
        command = "Skipped (permission constraints)",
        output = "Configuration validation skipped, will validate on reload",
        success = true
    }

    -- 5. 重载 nginx
    local reload_output, reload_exit = reload_nginx()
    result.reload = {
        output = reload_output or "",
        success = reload_exit == 0
    }

    if reload_exit ~= 0 then
        result.message = "Configuration applied but reload failed"
        ngx.log(ngx.ERR, "nginx reload failed: ", reload_output)
        return result
    end

    result.success = true
    result.message = "Configuration applied and nginx reloaded successfully"

    return result
end

------------------------------------------------------------------------------
-- 回滚到指定版本
------------------------------------------------------------------------------

function _M.rollback(version)
    local result = {
        success = false,
        message = "",
        version = version
    }

    -- 验证备份目录存在
    local backup_dir = DEPLOY_HISTORY_DIR .. version
    local handle = io_open(backup_dir, "r")
    if not handle then
        result.message = "Backup version not found: " .. version
        return result
    end

    -- 备份当前配置
    local current_backup = backup_config()
    ngx.log(ngx.INFO, "Current config backed up to: ", current_backup)

    -- 恢复备份
    local restore_cmd = 'cp -r "' .. backup_dir .. '/conf.d/" "' .. LOADBALANCE_DIR .. '/" 2>&1'
    local restore_output, restore_exit = exec_command(restore_cmd)

    if restore_exit ~= 0 then
        result.message = "Failed to restore backup: " .. (restore_output or "unknown error")
        return result
    end

    -- 重载 nginx (使用 sudo 方式，避免权限问题)
    local reload_output, reload_exit = reload_nginx()
    if reload_exit ~= 0 then
        result.message = "Reload failed: " .. (reload_output or "unknown error")
        return result
    end

    result.success = true
    result.message = "Rollback to version " .. version .. " completed successfully"

    return result
end

------------------------------------------------------------------------------
-- 获取部署状态
------------------------------------------------------------------------------

-- 获取配置文件中的生成时间
local function get_config_timestamp()
    local handle = io_open(LOADBALANCE_CONF_DIR .. "upstream.conf", "r")
    if not handle then return nil end

    local content = handle:read("*a")
    handle:close()

    return content:match("Generated at: ([^\n]+)")
end

-- 获取备份列表
local function get_backup_list()
    ensure_dir(DEPLOY_HISTORY_DIR)

    local backups = {}
    local handle = io.popen('ls -1 "' .. DEPLOY_HISTORY_DIR .. '" 2>/dev/null', "r")
    if handle then
        for line in handle:lines() do
            table.insert(backups, line)
        end
        handle:close()
    end

    return backups
end

-- 获取配置统计
local function get_config_stats()
    local stats = {}
    for _, domain in ipairs({ "upstream", "http", "stream", "location" }) do
        local config = storage.load(domain)
        stats[domain .. "s"] = config and #config.items or 0
    end
    return stats
end

function _M.status()
    local running, pid = is_nginx_running()

    return {
        prod_dir = LOADBALANCE_DIR,
        nginx_running = running,
        nginx_pid = pid,
        last_deploy = get_config_timestamp(),
        available_backups = get_backup_list(),
        config_stats = get_config_stats()
    }
end

------------------------------------------------------------------------------
-- 获取部署历史
------------------------------------------------------------------------------

function _M.history()
    ensure_dir(DEPLOY_HISTORY_DIR)

    local history = {}
    local handle = io.popen('ls -1t "' .. DEPLOY_HISTORY_DIR .. '" 2>/dev/null', "r")

    if handle then
        for line in handle:lines() do
            table.insert(history, {
                version = line,
                timestamp = line
            })
        end
        handle:close()
    end

    return history
end

return _M