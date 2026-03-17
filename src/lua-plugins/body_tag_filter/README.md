# body_tag_filter

根据请求体中的标签字段决定是否拦截请求。

## 功能说明

解析 HTTP 请求体中的特定字段（如 `gray`），根据配置的黑白名单决定：
- 返回自定义错误码拦截请求
- 允许请求转发到后端服务器

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| tag_field | string | 否 | `gray` | 要检查的字段名 |
| block_values | string[] | 否 | `[]` | 需要拦截的标签值列表 |
| allow_values | string[] | 否 | `[]` | 允许通过的标签值列表（优先级更高） |
| reject_code | number | 否 | `403` | 拒绝时的 HTTP 状态码 |
| reject_message | string | 否 | `Request blocked` | 拒绝时的响应消息 |
| reject_headers | table | 否 | `{}` | 拒绝时的额外响应头 |
| max_body_size | number | 否 | `1048576` | 最大请求体大小（字节） |
| content_types | string[] | 否 | 见下方 | 支持的内容类型 |

### 默认支持的 Content-Type

- `application/json`
- `application/x-www-form-urlencoded`
- `text/plain`

### 示例数据

```lua
{
    tag_field = "gray",
    block_values = {"true", "1", "yes"},
    reject_code = 403,
    reject_message = "Gray traffic blocked",
    reject_headers = {
        ["X-Block-Source"] = "body_tag_filter"
    }
}
```

## 使用示例

### 场景 1: 拦截灰度流量

拦截请求体中 `gray=true` 的请求：

```lua
{
    tag_field = "gray",
    block_values = {"true", "1", "yes"},
    reject_code = 503,
    reject_message = "Service temporarily unavailable for gray traffic"
}
```

### 场景 2: 白名单模式

只允许特定标签值的请求通过：

```lua
{
    tag_field = "env",
    allow_values = {"production", "prod"},
    reject_code = 403,
    reject_message = "Access denied"
}
```

### nginx.conf

```nginx
http {
    lua_package_path "/path/to/plugins/?.lua;;";

    init_worker_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        local ok, err = filter.init_worker({
            tag_field = "gray",
            block_values = {"true", "1"},
            reject_code = 403,
            reject_message = "Gray traffic blocked"
        })
        if not ok then
            ngx.log(ngx.ERR, "plugin init failed: ", err)
        end
    }

    server {
        listen 80;
        server_name localhost;

        location /api/ {
            # 请求预处理（读取请求体，判断是否拦截）
            rewrite_by_lua_block {
                require("body_tag_filter.body_tag_filter").prerouting()
            }

            # 路由决策（执行拦截）
            access_by_lua_block {
                require("body_tag_filter.body_tag_filter").postrouting()
            }

            # 响应头处理
            header_filter_by_lua_block {
                require("body_tag_filter.body_tag_filter").header_filter()
            }

            # 代理到后端
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

### 测试验证

```bash
# 1. JSON 格式请求体 - 被拦截
curl -X POST http://localhost/api/test \
    -H "Content-Type: application/json" \
    -d '{"gray": "true", "data": "test"}'
# 预期: 403 Gray traffic blocked

# 2. JSON 格式请求体 - 放行
curl -X POST http://localhost/api/test \
    -H "Content-Type: application/json" \
    -d '{"gray": "false", "data": "test"}'
# 预期: 请求转发到后端

# 3. Form 格式请求体
curl -X POST http://localhost/api/test \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "gray=true&name=test"
# 预期: 403 Gray traffic blocked

# 4. 纯文本格式
curl -X POST http://localhost/api/test \
    -H "Content-Type: text/plain" \
    -d "gray=true"
# 预期: 403 Gray traffic blocked
```

## 工作原理

```
请求进入
    │
    ▼
检查请求方法（GET/HEAD 无请求体）
    │
    ▼
检查 Content-Type 是否支持
    │
    ▼
读取请求体（限制最大大小）
    │
    ▼
根据 Content-Type 解析请求体
    │
    ├── JSON: 解析 "field": "value"
    ├── Form: 解析 field=value
    └── Text: 解析 field=value 或 field: value
    │
    ▼
匹配黑白名单
    │
    ├── 在 allow_values 中 → 放行
    ├── 在 block_values 中 → 拦截
    └── 不在任何列表 → 放行
    │
    ▼
拦截: 返回 reject_code 和 reject_message
放行: 转发到后端服务器
```

## 注意事项

1. **请求体大小限制**: 默认最大 1MB，超过限制的请求体将跳过检查
2. **解析优先级**: `allow_values` 优先级高于 `block_values`
3. **性能考虑**: 请求体会被读取到内存中，注意控制 `max_body_size`
4. **请求方法**: GET 和 HEAD 请求没有请求体，会直接放行