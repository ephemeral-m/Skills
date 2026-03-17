-- 部署控制模块
-- 管理配置的应用

local _M = {
    _VERSION = "2.0.0"
}

local generator = require "admin.generator"
local storage = require "admin.storage"
local utils = require "admin.utils"
local io_open = io.open

------------------------------------------------------------------------------
-- 路径常量
------------------------------------------------------------------------------

-- 获取负载均衡目录的绝对路径
local function get_loadbalance_dir()
    local prefix = ngx.config.prefix()
    prefix = prefix:gsub("/+$", "")

    local parts = {}
    for part in prefix:gmatch("[^/]+") do
        table.insert(parts, part)
    end

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
local LOADBALANCE_PID_FILE = LOADBALANCE_DIR .. "/logs/nginx.pid"

------------------------------------------------------------------------------
-- 工具函数
------------------------------------------------------------------------------

-- 获取 nginx 可执行文件路径
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
        cmd = nginx_bin .. ' -s reload -p "' .. LOADBALANCE_DIR .. '" -c nginx.conf 2>&1'
    else
        cmd = nginx_bin .. ' -p "' .. LOADBALANCE_DIR .. '" -c nginx.conf 2>&1'
    end

    return exec_command(cmd)
end

-- 生成配置文件头部
local function config_header(name)
    return string.format("# Auto-generated %s configuration\n# Generated at: %s\n\n",
        name, ngx.localtime())
end

------------------------------------------------------------------------------
-- 预览生成的配置
------------------------------------------------------------------------------

function _M.preview()
    local configs = generator.generate_all()

    local sections = {
        { name = "HTTP Upstreams", configs = configs.upstream_configs },
        { name = "Stream Upstreams", configs = configs.stream_upstream_configs },
        { name = "HTTP Servers", configs = configs.http_servers },
        { name = "Stream Servers", configs = configs.stream_servers }
    }

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
        stream_upstreams = table.concat(configs.stream_upstream_configs, "\n"),
        http_servers = table.concat(configs.http_servers, "\n"),
        stream_servers = table.concat(configs.stream_servers, "\n"),
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
        reload = nil
    }

    -- 1. 准备环境
    prepare_environment()

    -- 2. 生成并写入配置
    local configs = generator.generate_all()

    -- 写入 HTTP upstream 配置
    write_config_file("upstream.conf", "HTTP upstream", configs.upstream_configs)

    -- 写入 HTTP server 配置
    write_config_file("http.conf", "HTTP server", configs.http_servers)

    -- 写入 stream 配置
    local stream_content = config_header("stream server")
    if #configs.stream_upstream_configs > 0 then
        stream_content = stream_content .. "# Stream Upstreams\n" ..
                         table.concat(configs.stream_upstream_configs, "\n") .. "\n"
    end
    stream_content = stream_content .. table.concat(configs.stream_servers, "\n")
    generator.write_config(LOADBALANCE_CONF_DIR .. "stream.conf", stream_content)

    -- 3. 重载 nginx
    local reload_output, reload_exit = reload_nginx()
    result.reload = {
        output = reload_output or "",
        success = reload_exit == 0
    }

    if reload_exit ~= 0 then
        result.message = "Configuration applied but reload failed: " .. (reload_output or "")
        ngx.log(ngx.ERR, "nginx reload failed: ", reload_output)
        return result
    end

    result.success = true
    result.message = "Configuration applied and nginx reloaded successfully"

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

-- 获取配置统计
local function get_config_stats()
    local stats = {}
    for _, domain in ipairs({ "servers", "server-groups", "routes", "listeners-http", "listeners-tcp" }) do
        local config = storage.load(domain)
        stats[domain] = config and config.items and #config.items or 0
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
        config_stats = get_config_stats()
    }
end

return _M