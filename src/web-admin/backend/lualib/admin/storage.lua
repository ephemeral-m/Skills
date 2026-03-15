-- JSON 文件存储层
-- 提供配置的持久化存储、版本管理和回滚支持

local _M = {}
local cjson = require "cjson.safe"
local io_open = io.open

-- 数据目录
local DATA_DIR = ngx.config.prefix() .. "../data/configs/"

-- 获取配置文件路径
local function get_path(domain)
    return DATA_DIR .. domain .. ".json"
end

-- 获取历史文件路径
local function get_history_path(domain, version)
    return DATA_DIR .. "history/" .. domain .. "_" .. version .. ".json"
end

-- 加载配置
function _M.load(domain)
    local path = get_path(domain)
    local file, err = io_open(path, "r")
    if not file then
        -- 文件不存在，返回默认结构
        if err and err:find("No such file") then
            return {
                version = 0,
                updated_at = nil,
                items = {}
            }
        end
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

-- 保存配置（带版本管理）
function _M.save(domain, data)
    -- 确保数据目录存在
    local mkdir_cmd = 'mkdir -p "' .. DATA_DIR .. '"'
    os.execute(mkdir_cmd)
    os.execute('mkdir -p "' .. DATA_DIR .. 'history"')

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
    local path = get_path(domain)
    local file, err = io_open(path, "w")
    if not file then
        return nil, "Failed to open file: " .. (err or "unknown")
    end

    local encoded = cjson.encode(data)
    file:write(encoded)
    file:close()

    -- 更新共享字典缓存
    local cache = ngx.shared.config_cache
    if cache then
        cache:set(domain, encoded)
    end

    return true
end

-- 回滚到指定版本
function _M.rollback(domain, version)
    local history_path = get_history_path(domain, version)
    local file, err = io_open(history_path, "r")
    if not file then
        return nil, "Version " .. version .. " not found: " .. (err or "unknown")
    end

    local content = file:read("*a")
    file:close()

    local data, decode_err = cjson.decode(content)
    if not data then
        return nil, "JSON decode error: " .. (decode_err or "unknown")
    end

    -- 保存回滚后的配置
    return _M.save(domain, data)
end

-- 获取版本历史
function _M.history(domain)
    local history_dir = DATA_DIR .. "history/"
    local cmd = 'ls "' .. history_dir .. domain .. '_*.json" 2>/dev/null'
    local handle = io.popen(cmd)
    if not handle then
        return {}
    end

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

-- 删除配置项
function _M.delete_item(domain, id)
    local data = _M.load(domain)
    if not data then
        return nil, "Config not found"
    end

    local found = false
    local new_items = {}
    for _, item in ipairs(data.items) do
        if item.id ~= id then
            table.insert(new_items, item)
        else
            found = true
        end
    end

    if not found then
        return nil, "Item not found: " .. id
    end

    data.items = new_items
    return _M.save(domain, data)
end

-- 获取单个配置项
function _M.get_item(domain, id)
    local data = _M.load(domain)
    if not data then
        return nil, "Config not found"
    end

    for _, item in ipairs(data.items) do
        if item.id == id then
            return item
        end
    end

    return nil, "Item not found: " .. id
end

-- 更新单个配置项
function _M.update_item(domain, id, item_data)
    local data = _M.load(domain)
    if not data then
        return nil, "Config not found"
    end

    local found = false
    for i, item in ipairs(data.items) do
        if item.id == id then
            item_data.id = id  -- 保持 ID 不变
            data.items[i] = item_data
            found = true
            break
        end
    end

    if not found then
        return nil, "Item not found: " .. id
    end

    return _M.save(domain, data)
end

-- 添加配置项
function _M.add_item(domain, item_data)
    local data = _M.load(domain)
    if not data then
        data = { version = 0, items = {} }
    end

    -- 生成 ID
    if not item_data.id then
        item_data.id = ngx.md5(ngx.now() .. cjson.encode(item_data)):sub(1, 12)
    end

    table.insert(data.items, item_data)
    return _M.save(domain, data), item_data.id
end

return _M