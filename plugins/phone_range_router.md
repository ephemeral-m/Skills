# phone_range_router 使用说明

## 功能

根据请求头 `phone-number` 字段值范围路由到不同后端。

## Nginx 配置

```nginx
http {
    lua_package_path "/path/to/plugins/?.lua;;";

    upstream backend_a { server 192.168.1.10:8080; }
    upstream backend_b { server 192.168.2.10:8080; }
    upstream default_backend { server 192.168.100.10:8080; }

    init_worker_by_lua_block {
        local plugin = require "phone_range_router"
        local ok, err = plugin.init_worker({
            ranges = {
                {min = "13000000000", max = "13999999999", upstream = "backend_a"},
                {min = "15000000000", max = "15999999999", upstream = "backend_b"}
            },
            default_upstream = "default_backend",
            header_name = "phone-number"
        })
        if not ok then
            ngx.log(ngx.ERR, "init failed: ", err)
        end
    }

    server {
        listen 80;
        set $upstream default_backend;

        location /api/ {
            rewrite_by_lua_block {
                require("phone_range_router").prerouting()
            }
            access_by_lua_block {
                require("phone_range_router").postrouting()
            }
            proxy_pass http://$upstream;
            header_filter_by_lua_block {
                require("phone_range_router").header_filter()
            }
        }
    }
}
```

## 测试

```bash
curl -H "phone-number: 13812345678" http://localhost/api/test
# 响应头: X-Phone: 13812345678, X-Upstream: backend_a
```

## 配置项

| 配置项 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `ranges` | array | 否 | 区间配置 |
| `ranges[].min` | string | 是 | 起始号码 |
| `ranges[].max` | string | 是 | 结束号码 |
| `ranges[].upstream` | string | 是 | 上游名称 |
| `default_upstream` | string | 否 | 默认上游 |
| `header_name` | string | 否 | 请求头名，默认 `phone-number` |