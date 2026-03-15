-- JSON 文件存储层
-- 提供配置的持久化存储、版本管理和回滚支持

local _M = {}
local cjson = require "cjson.safe"
local io_open = io.open

-- 数据目录
local DATA_DIR = ngx.config.prefix() .. "../data/configs/"

------------------------------------------------------------------------------
-- 工具函数
------------------------------------------------------------------------------

-- 获取配置文件路径
local function get_path(domain)
    return DATA_DIR .. domain .. ".json"
end

-- 获取历史文件路径
local function get_history_path(domain, version)
    return DATA_DIR .. "history/" .. domain .. "_" .. version .. ".json"
end

-- 确保目录存在
local function ensure_dirs()
    os.execute('mkdir -p "' .. DATA_DIR .. '"')
    os.execute('mkdir -p "' .. DATA_DIR .. 'history"')
end

-- 读取 JSON 文件
local function read_json_file(path)
    local file, err = io_open(path, "r")
    if not file then
        return nil, err
    end

    local content = file:read("*a")
    file:close()

    local data, decode_err = cjson.decode(content)
    if not data then
        return nil, "JSON decode error: " .. (decode_err or "unknown")
    end

    return data
end

-- 写入 JSON 文件
local function write_json_file(path, data)
    local file, err = io_open(path, "w")
    if not file then
        return nil, "Failed to open file: " .. (err or "unknown")
    end

    file:write(cjson.encode(data))
    file:close()

    return true
end

------------------------------------------------------------------------------
-- 公共 API
------------------------------------------------------------------------------

-- 加载配置
function _M.load(domain)
    local path = get_path(domain)
    local data, err = read_json_file(path)

    if not data then
        -- 文件不存在，返回默认结构
        if err and err:find("No such file") then
            return { version = 0, updated_at = nil, items = {} }
        end
        return nil, err
    end

    return data
end

-- 保存配置（带版本管理）
function _M.save(domain, data)
    ensure_dirs()

    -- 加载现有配置获取版本号
    local existing = _M.load(domain)
    local old_version = existing and existing.version or 0

    -- 备份旧版本
    if old_version > 0 then
        local old_path = get_path(domain)
        local history_path = get_history_path(domain, old_version)
        os.execute('cp "' .. old_path .. '" "' .. history_path .. '"')
    end

    -- 更新版本和时间戳
    data.version = old_version + 1
    data.updated_at = ngx.localtime()

    -- 写入新配置
    local ok, err = write_json_file(get_path(domain), data)
    if not ok then return nil, err end

    -- 更新共享字典缓存
    local cache = ngx.shared.config_cache
    if cache then
        cache:set(domain, cjson.encode(data))
    end

    return true
end

-- 回滚到指定版本
function _M.rollback(domain, version)
    local data, err = read_json_file(get_history_path(domain, version))
    if not data then
        return nil, "Version " .. version .. " not found: " .. (err or "unknown")
    end

    return _M.save(domain, data)
end

-- 获取版本历史
function _M.history(domain)
    local cmd = 'ls "' .. DATA_DIR .. 'history/' .. domain .. '_*.json" 2>/dev/null'
    local handle = io.popen(cmd)
    if not handle then return {} end

    local result = handle:read("*a")
    handle:close()

    local versions = {}
    for file_path in result:gmatch("[^\n]+") do
        local version = file_path:match(domain .. "_(%d+)%.json$")
        if version then
            table.insert(versions, tonumber(version))
        end
    end

    table.sort(versions, function(a, b) return a > b end)
    return versions
end

------------------------------------------------------------------------------
-- CRUD 操作
------------------------------------------------------------------------------

-- 获取单个配置项
function _M.get_item(domain, id)
    local data = _M.load(domain)
    if not data then return nil, "Config not found" end

    for _, item in ipairs(data.items) do
        if item.id == id then return item end
    end

    return nil, "Item not found: " .. id
end

-- 添加配置项
function _M.add_item(domain, item_data)
    local data = _M.load(domain) or { version = 0, items = {} }

    -- 生成 ID
    if not item_data.id then
        item_data.id = ngx.md5(ngx.now() .. cjson.encode(item_data)):sub(1, 12)
    end

    table.insert(data.items, item_data)
    return _M.save(domain, data), item_data.id
end

-- 更新单个配置项
function _M.update_item(domain, id, item_data)
    local data = _M.load(domain)
    if not data then return nil, "Config not found" end

    for i, item in ipairs(data.items) do
        if item.id == id then
            item_data.id = id  -- 保持 ID 不变
            data.items[i] = item_data
            return _M.save(domain, data)
        end
    end

    return nil, "Item not found: " .. id
end

-- 删除配置项
function _M.delete_item(domain, id)
    local data = _M.load(domain)
    if not data then return nil, "Config not found" end

    local new_items = {}
    local found = false

    for _, item in ipairs(data.items) do
        if item.id == id then
            found = true
        else
            table.insert(new_items, item)
        end
    end

    if not found then return nil, "Item not found: " .. id end

    data.items = new_items
    return _M.save(domain, data)
end

return _M