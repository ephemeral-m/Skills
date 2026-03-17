# gray_router

根据 HTTP 请求体中的灰度标签决定返回灰度响应或正常转发到后端服务器。

## 功能说明

1. 检查 HTTP 请求消息体中是否存在指定的灰度标签（默认：`gray=true`）
2. 如果存在灰度标签，返回配置的灰度响应（状态码、头部、响应体）
3. 如果不存在灰度标签，继续正常转发到默认后端服务器

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| response | table | 否 | - | 灰度响应配置 |
| response.status | number | 否 | 200 | 响应状态码 |
| response.headers | table | 否 | {} | 响应头键值对 |
| response.body | string | 否 | "" | 响应体内容 |
| tag_pattern | string | 否 | "gray=true" | 灰度标签匹配模式 |

### 示例数据

```lua
{
    tag_pattern = "gray=true",
    response = {
        status = 200,
        headers = {
            ["X-Gray"] = "true",
            ["Content-Type"] = "application/json"
        },
        body = '{"code": 0, "message": "gray release response"}'
    }
}
```

## 使用示例

### nginx.conf

```nginx
http {
    lua_package_path "/path/to/plugins/?.lua;;";

    upstream backend {
        server 192.168.1.10:8080;
        keepalive 32;
    }

    init_worker_by_lua_block {
        local plugin = require "gray_router.gray_router"
        local ok, err = plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                headers = {
                    ["X-Gray"] = "true",
                    ["Content-Type"] = "application/json"
                },
                body = '{"code": 0, "message": "gray release response"}'
            }
        })
        if not ok then
            ngx.log(ngx.ERR, "plugin init failed: ", err)
        end
    }

    server {
        listen 80;
        server_name localhost;

        location /api/ {
            # 确保请求体可读
            lua_need_request_body on;
            client_body_buffer_size 1m;
            client_max_body_size 10m;

            # 请求预处理：读取请求体检查灰度标签
            rewrite_by_lua_block {
                require("gray_router.gray_router").prerouting()
            }

            # 路由决策：返回灰度响应或继续转发
            access_by_lua_block {
                require("gray_router.gray_router").postrouting()
            }

            # 代理到后端服务器
            proxy_pass http://backend;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}
```

### 测试验证

```bash
# 测试 1: 请求体包含 gray=true，返回灰度响应
curl -X POST http://localhost/api/test \
    -H "Content-Type: application/json" \
    -d '{"name": "test", "gray": true}'
# 预期响应:
# HTTP/1.1 200 OK
# X-Gray: true
# Content-Type: application/json
# {"code": 0, "message": "gray release response"}

# 测试 2: 请求体不包含 gray=true，转发到后端
curl -X POST http://localhost/api/test \
    -H "Content-Type: application/json" \
    -d '{"name": "test"}'
# 预期: 请求被转发到 backend 服务器

# 测试 3: GET 请求无请求体，直接转发
curl http://localhost/api/test
# 预期: 请求被转发到 backend 服务器

# 测试 4: 表单格式请求体
curl -X POST http://localhost/api/test \
    -d "name=test&gray=true&value=123"
# 预期: 返回灰度响应
```

## 工作原理

```
┌─────────────────────────────────────────────────────────────┐
│                      请求处理流程                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  HTTP 请求 ──→ prerouting ──→ 读取请求体                    │
│                    │                                        │
│                    ▼                                        │
│              检查 gray=true                                 │
│                    │                                        │
│         ┌─────────┴─────────┐                               │
│         │                   │                               │
│    存在标签              不存在标签                          │
│         │                   │                               │
│         ▼                   ▼                               │
│    postrouting         postrouting                          │
│         │                   │                               │
│         ▼                   ▼                               │
│   返回灰度响应         proxy_pass                           │
│                          │                                  │
│                          ▼                                  │
│                    后端服务器                                │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## 注意事项

1. **请求体读取**: 需要配置 `lua_need_request_body on` 确保请求体可读
2. **大文件处理**: 对于超过 `client_body_buffer_size` 的请求体，只读取前 1MB 进行匹配
3. **HTTP 方法**: 只对 POST/PUT/PATCH 方法检查请求体，GET/DELETE 等直接转发
4. **模式匹配**: 使用纯字符串匹配，不解析为正则表达式

## 扩展配置

### 多条件灰度

可以扩展插件支持多种灰度标签组合：

```lua
{
    tag_pattern = "gray=true",  -- 基础标签
    response = {
        status = 200,
        headers = {
            ["X-Gray-Version"] = "v2",
            ["X-Gray-Ratio"] = "10%"
        },
        body = '{"code": 0, "data": {"version": "v2"}}'
    }
}
```

### JSON 格式响应

```lua
{
    response = {
        status = 200,
        headers = {
            ["Content-Type"] = "application/json; charset=utf-8"
        },
        body = [[
{
    "code": 0,
    "message": "success",
    "data": {
        "version": "gray-v1.0.0",
        "timestamp": "2024-01-01T00:00:00Z"
    }
}
        ]]
    }
}
```

### HTML 格式响应

```lua
{
    response = {
        status = 200,
        headers = {
            ["Content-Type"] = "text/html; charset=utf-8"
        },
        body = [[
<!DOCTYPE html>
<html>
<head><title>Gray Release</title></head>
<body>
    <h1>Welcome to Gray Environment</h1>
</body>
</html>
        ]]
    }
}
```