# phone_range_router

根据手机号区间路由到不同后端服务器。

## 功能说明

读取请求头中的手机号，根据配置的号段区间匹配对应的上游服务器。

## 数据格式

### 配置项

| 字段 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| ranges | table[] | 是 | - | 号码区间配置数组 |
| default_upstream | string | 否 | default_backend | 默认上游 |
| header_name | string | 否 | phone-number | 请求头字段名 |

### range 配置

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| min | string | 是 | 起始号码（11位手机号） |
| max | string | 是 | 结束号码（11位手机号） |
| upstream | string | 是 | 目标上游名称 |

### 示例数据

```lua
{
    ranges = {
        {min = "13000000000", max = "13999999999", upstream = "backend_a"},
        {min = "15000000000", max = "15999999999", upstream = "backend_b"}
    },
    default_upstream = "default_backend",
    header_name = "phone-number"
}
```

## 使用方法

### 1. 部署插件

```bash
# 将插件目录复制到 OpenResty 的 lua 目录
cp -r phone_range_router /usr/local/openresty/lualib/
```

### 2. 引用配置

在 `nginx.conf` 的 `http` 块中引入插件配置：

```nginx
http {
    # 引入插件配置（包含 upstream 定义和 init_worker）
    include plugins/phone_range_router/nginx.conf.example;

    server {
        listen 80;
        # ... server 配置
    }
}
```

或直接复制 `nginx.conf.example` 内容到你的配置中。

### 3. 完整配置示例

参见 [nginx.conf.example](./nginx.conf.example)

## 测试验证

```bash
# 130 号段 → backend_a
curl -H "phone-number: 13812345678" http://localhost/api/test
# 预期响应头: X-Upstream: backend_a

# 150 号段 → backend_b
curl -H "phone-number: 15812345678" http://localhost/api/test
# 预期响应头: X-Upstream: backend_b

# 其他号段 → default_backend
curl -H "phone-number: 18812345678" http://localhost/api/test
# 预期响应头: X-Upstream: default_backend

# 无手机号 → default_backend
curl http://localhost/api/test
# 预期响应头: X-Upstream: default_backend
```

## 注意事项

1. 手机号必须是 11 位数字，其他格式会被视为无效号码
2. 区间配置会按起始号码排序后匹配
3. 无效号码会路由到 default_upstream

## 文件说明

| 文件 | 说明 |
|------|------|
| `phone_range_router.lua` | 插件主文件 |
| `nginx.conf.example` | 完整可用的 Nginx 配置示例 |
| `README.md` | 本文档 |