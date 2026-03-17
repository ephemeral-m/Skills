-- JSON 文件存储层

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

-- 确保目录存在
local function ensure_dirs()
    os.execute('mkdir -p "' .. DATA_DIR .. '"')
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
        if err and err:find("No such file") then
            return { version = 0, updated_at = nil, items = {} }
        end
        return nil, err
    end

    return data
end

-- 保存配置
function _M.save(domain, data)
    ensure_dirs()

    local existing = _M.load(domain)
    local old_version = existing and existing.version or 0

    data.version = old_version + 1
    data.updated_at = ngx.localtime()

    local ok, err = write_json_file(get_path(domain), data)
    if not ok then return nil, err end

    -- 更新共享字典缓存
    local cache = ngx.shared.config_cache
    if cache then
        cache:set(domain, cjson.encode(data))
    end

    return true
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
            item_data.id = id
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