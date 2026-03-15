-- 部署控制模块
-- 管理配置的应用、验证和回滚

local _M = {
    _VERSION = "1.0.0"
}

local cjson = require "cjson.safe"
local generator = require "admin.generator"
local storage = require "admin.storage"
local io_open = io.open

-- 生产 OpenResty 配置路径
local PROD_DIR = ngx.config.prefix() .. "../../../openresty-prod/"
local PROD_CONF_DIR = PROD_DIR .. "conf.d/"
local PROD_NGINX_CONF = PROD_DIR .. "nginx.conf"
local PROD_PID_FILE = PROD_DIR .. "logs/nginx.pid"

-- 部署历史目录
local DEPLOY_HISTORY_DIR = PROD_DIR .. "deploy_history/"

-- 获取生产 nginx 可执行文件路径
local function get_nginx_binary()
    -- 尝试多个可能的路径
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

    return "nginx"  -- 回退到系统 PATH 中的 nginx
end

-- 执行 shell 命令
local function exec_command(cmd)
    local handle = io.popen(cmd .. " 2>&1", "r")
    if not handle then
        return nil, "Failed to execute command"
    end

    local output = handle:read("*a")
    local success, reason, exit_code = handle:close()

    -- io.pclose 返回三个值: success, exit_reason, exit_code
    -- exit_code 可能是 nil，需要处理
    exit_code = exit_code or (success and 0 or 1)

    return output, exit_code
end

-- 确保目录存在
local function ensure_dir(dir)
    local cmd = 'mkdir -p "' .. dir .. '"'
    os.execute(cmd)
end

-- 备份当前配置
local function backup_config()
    ensure_dir(DEPLOY_HISTORY_DIR)

    local timestamp = os.date("%Y%m%d_%H%M%S")
    local backup_dir = DEPLOY_HISTORY_DIR .. timestamp

    ensure_dir(backup_dir)

    -- 备份 conf.d 目录
    local cmd = 'cp -r "' .. PROD_CONF_DIR .. '" "' .. backup_dir .. '/" 2>/dev/null || true'
    os.execute(cmd)

    return timestamp
end

------------------------------------------------------------------------------
-- 预览生成的配置
------------------------------------------------------------------------------
function _M.preview()
    local configs = generator.generate_all()

    local preview_result = {
        upstreams = table.concat(configs.upstreams, "\n"),
        http_servers = table.concat(configs.http_servers, "\n"),
        stream_servers = table.concat(configs.stream_servers, "\n"),
        locations = table.concat(configs.locations, "\n")
    }

    -- 生成完整预览
    local full_preview = {}
    table.insert(full_preview, "# ========================================")
    table.insert(full_preview, "# Generated Nginx Configuration Preview")
    table.insert(full_preview, "# Generated at: " .. ngx.localtime())
    table.insert(full_preview, "# ========================================")
    table.insert(full_preview, "")

    if #configs.upstreams > 0 then
        table.insert(full_preview, "# ========== Upstreams ==========")
        for _, conf in ipairs(configs.upstreams) do
            table.insert(full_preview, conf)
        end
    end

    if #configs.http_servers > 0 then
        table.insert(full_preview, "# ========== HTTP Servers ==========")
        for _, conf in ipairs(configs.http_servers) do
            table.insert(full_preview, conf)
        end
    end

    if #configs.stream_servers > 0 then
        table.insert(full_preview, "# ========== Stream Servers ==========")
        for _, conf in ipairs(configs.stream_servers) do
            table.insert(full_preview, conf)
        end
    end

    preview_result.full = table.concat(full_preview, "\n")

    return preview_result
end

------------------------------------------------------------------------------
-- 应用配置
------------------------------------------------------------------------------
function _M.apply()
    local result = {
        success = false,
        message = "",
        backup_id = nil,
        validation = nil,
        reload = nil
    }

    -- 1. 确保目录存在
    ensure_dir(PROD_DIR)
    ensure_dir(PROD_CONF_DIR)

    -- 2. 备份当前配置
    local backup_id = backup_config()
    result.backup_id = backup_id
    ngx.log(ngx.INFO, "Config backed up to: ", backup_id)

    -- 3. 生成配置
    local configs = generator.generate_all()

    -- 4. 写入配置文件
    -- 写入 upstream 配置
    local upstream_file = PROD_CONF_DIR .. "upstream.conf"
    local upstream_content = "# Auto-generated upstream configuration\n" ..
                             "# Generated at: " .. ngx.localtime() .. "\n\n" ..
                             table.concat(configs.upstreams, "\n")
    generator.write_config(upstream_file, upstream_content)

    -- 写入 location 配置
    local location_file = PROD_CONF_DIR .. "locations.conf"
    local location_content = "# Auto-generated location configuration\n" ..
                             "# Generated at: " .. ngx.localtime() .. "\n\n" ..
                             table.concat(configs.locations, "\n")
    generator.write_config(location_file, location_content)

    -- 写入 http server 配置
    local http_file = PROD_CONF_DIR .. "http.conf"
    local http_content = "# Auto-generated HTTP server configuration\n" ..
                         "# Generated at: " .. ngx.localtime() .. "\n\n" ..
                         table.concat(configs.http_servers, "\n")
    generator.write_config(http_file, http_content)

    -- 写入 stream server 配置
    local stream_file = PROD_CONF_DIR .. "stream.conf"
    local stream_content = "# Auto-generated stream server configuration\n" ..
                           "# Generated at: " .. ngx.localtime() .. "\n\n" ..
                           table.concat(configs.stream_servers, "\n")
    generator.write_config(stream_file, stream_content)

    -- 5. 验证配置
    local nginx_bin = get_nginx_binary()
    local test_cmd = nginx_bin .. ' -t -c "' .. PROD_NGINX_CONF .. '"'
    local test_output, test_exit = exec_command(test_cmd)

    result.validation = {
        command = test_cmd,
        output = test_output,
        success = test_exit == 0
    }

    if test_exit ~= 0 then
        result.message = "Configuration validation failed"
        ngx.log(ngx.ERR, "nginx -t failed: ", test_output)
        return result
    end

    -- 6. 重载 nginx
    local reload_output, reload_exit
    local pid_file = PROD_PID_FILE

    -- 检查 nginx 是否在运行
    local pid_handle = io_open(pid_file, "r")
    if pid_handle then
        local pid = pid_handle:read("*n")
        pid_handle:close()

        if pid then
            -- 发送 HUP 信号重载配置
            local reload_cmd = "kill -HUP " .. pid .. " 2>&1"
            reload_output, reload_exit = exec_command(reload_cmd)
        else
            -- 启动 nginx
            local start_cmd = nginx_bin .. ' -c "' .. PROD_NGINX_CONF .. '"'
            reload_output, reload_exit = exec_command(start_cmd)
        end
    else
        -- nginx 未运行，启动它
        local start_cmd = nginx_bin .. ' -c "' .. PROD_NGINX_CONF .. '"'
        reload_output, reload_exit = exec_command(start_cmd)
    end

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

    -- 查找备份目录
    local backup_dir = DEPLOY_HISTORY_DIR .. version
    local handle = io_open(backup_dir, "r")
    if not handle then
        result.message = "Backup version not found: " .. version
        return result
    end
    -- 只是检查目录是否存在，不需要读取

    -- 备份当前配置
    local current_backup = backup_config()
    ngx.log(ngx.INFO, "Current config backed up to: ", current_backup)

    -- 恢复备份
    local restore_cmd = 'cp -r "' .. backup_dir .. '/conf.d/" "' .. PROD_DIR .. '/" 2>&1'
    local restore_output, restore_exit = exec_command(restore_cmd)

    if restore_exit ~= 0 then
        result.message = "Failed to restore backup: " .. (restore_output or "unknown error")
        return result
    end

    -- 验证并重载
    local nginx_bin = get_nginx_binary()
    local test_cmd = nginx_bin .. ' -t -c "' .. PROD_NGINX_CONF .. '"'
    local test_output, test_exit = exec_command(test_cmd)

    if test_exit ~= 0 then
        result.message = "Restored config validation failed: " .. test_output
        return result
    end

    -- 重载
    local pid_file = PROD_PID_FILE
    local pid_handle = io_open(pid_file, "r")
    if pid_handle then
        local pid = pid_handle:read("*n")
        pid_handle:close()

        if pid then
            local reload_cmd = "kill -HUP " .. pid .. " 2>&1"
            local reload_output, reload_exit = exec_command(reload_cmd)
            if reload_exit ~= 0 then
                result.message = "Reload failed: " .. (reload_output or "unknown error")
                return result
            end
        end
    end

    result.success = true
    result.message = "Rollback to version " .. version .. " completed successfully"

    return result
end

------------------------------------------------------------------------------
-- 获取部署状态
------------------------------------------------------------------------------
function _M.status()
    local status = {
        prod_dir = PROD_DIR,
        nginx_running = false,
        nginx_pid = nil,
        config_version = nil,
        last_deploy = nil,
        available_backups = {}
    }

    -- 检查 nginx 是否运行
    local pid_file = PROD_PID_FILE
    local pid_handle = io_open(pid_file, "r")
    if pid_handle then
        local pid = pid_handle:read("*n")
        pid_handle:close()

        if pid then
            -- 检查进程是否存在
            local check_cmd = "kill -0 " .. pid .. " 2>&1"
            local _, exit_code = exec_command(check_cmd)
            status.nginx_running = (exit_code == 0)
            status.nginx_pid = pid
        end
    end

    -- 获取配置版本
    local upstream_conf = PROD_CONF_DIR .. "upstream.conf"
    local conf_handle = io_open(upstream_conf, "r")
    if conf_handle then
        local content = conf_handle:read("*a")
        conf_handle:close()

        local version_match = content:match("Generated at: ([^\n]+)")
        status.last_deploy = version_match
    end

    -- 获取可用备份列表
    ensure_dir(DEPLOY_HISTORY_DIR)
    local list_cmd = 'ls -1 "' .. DEPLOY_HISTORY_DIR .. '" 2>/dev/null'
    local list_handle = io.popen(list_cmd, "r")
    if list_handle then
        for line in list_handle:lines() do
            table.insert(status.available_backups, line)
        end
        list_handle:close()
    end

    -- 获取配置统计
    local upstream_config = storage.load("upstream")
    local http_config = storage.load("http")
    local stream_config = storage.load("stream")
    local location_config = storage.load("location")

    status.config_stats = {
        upstreams = upstream_config and #upstream_config.items or 0,
        http_servers = http_config and #http_config.items or 0,
        stream_servers = stream_config and #stream_config.items or 0,
        locations = location_config and #location_config.items or 0
    }

    return status
end

------------------------------------------------------------------------------
-- 获取部署历史
------------------------------------------------------------------------------
function _M.history()
    ensure_dir(DEPLOY_HISTORY_DIR)

    local history = {}
    local list_cmd = 'ls -1t "' .. DEPLOY_HISTORY_DIR .. '" 2>/dev/null'
    local handle = io.popen(list_cmd, "r")

    if handle then
        for line in handle:lines() do
            table.insert(history, {
                version = line,
                timestamp = line  -- 目录名就是时间戳
            })
        end
        handle:close()
    end

    return history
end

return _M