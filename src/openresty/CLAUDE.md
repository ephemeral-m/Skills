# OpenResty 源码

OpenResty 是一个基于 Nginx 的全功能 Web 应用服务器，通过捆绑标准 Nginx 核心、大量第三方 Nginx 模块及其外部依赖构建而成。

## 版本信息

- OpenResty 版本: 1.29.2.1
- Nginx 核心: 1.29.2
- LuaJIT: 2.1-20251030
- ngx_lua: 0.10.29R2

## 目录结构

```
src/
├── configure          # OpenResty 配置脚本 (Perl)
├── bundle/            # 所有捆绑的模块和依赖
│   ├── nginx-1.29.2/          # Nginx 核心
│   ├── LuaJIT-2.1-20251030/   # LuaJIT 解释器
│   ├── ngx_lua-0.10.29R2/     # Lua-Nginx 模块 (核心)
│   ├── lua-resty-*/           # lua-resty 库系列
│   └── *-nginx-module-*/      # 第三方 Nginx 模块
├── patches/           # Nginx 补丁
└── util/              # 构建工具
```

## 核心模块

OpenResty 默认包含的主要模块（定义于 `src/configure`）：

| 模块 | 说明 |
|------|------|
| `ngx_devel_kit` | Nginx 开发工具包 |
| `echo-nginx-module` | echo 指令 |
| `ngx_lua` | Lua 脚本支持（核心） |
| `ngx_stream_lua` | Stream 模块 Lua 支持 |
| `headers-more-nginx-module` | HTTP 头操作 |
| `set-misc-nginx-module` | 变量操作扩展 |
| `memc-nginx-module` | Memcached 客户端 |
| `redis2-nginx-module` | Redis 客户端 |
| `srcache-nginx-module` | 缓存操作 |
| `rds-json-nginx-module` | RDS JSON 输出 |
| `encrypted-session-nginx-module` | 加密会话 |

可选模块（默认禁用）：
- `iconv-nginx-module` - 字符编码转换
- `drizzle-nginx-module` - MySQL/Drizzle 客户端
- `ngx_postgres` - PostgreSQL 客户端

## 构建命令

### Linux/macOS

```bash
cd src
./configure --prefix=/usr/local/openresty
make
make install
```

### 常用 configure 选项

```bash
# 启用 SSL
./configure --with-http_ssl_module

# 启用 stream 模块
./configure --with-stream --with-stream_ssl_module

# 禁用特定模块
./configure --without-http_lua_module

# 查看所有选项
./configure --help
```

### 依赖

构建前需安装：
- PCRE (正则表达式)
- OpenSSL (SSL 支持)
- zlib (压缩)
- Perl (配置脚本)

## 模块开发

Nginx 模块典型结构（位于 `src/bundle/*-nginx-module-*/`）：

```
module-name/
├── config              # 模块构建配置
├── src/
│   ├── ngx_http_*.c    # 模块实现
│   └── ngx_http_*.h    # 头文件
├── t/
│   └── *.t             # 测试文件 (Test::Nginx 格式)
└── valgrind.suppress   # Valgrind 抑制规则
```

## lua-resty 库

位于 `src/bundle/lua-resty-*/`，提供 Lua 层面的功能：

- `lua-resty-core` - 核心 API
- `lua-resty-mysql` - MySQL 客户端
- `lua-resty-redis` - Redis 客户端
- `lua-resty-dns` - DNS 客户端
- `lua-resty-websocket` - WebSocket 支持
- `lua-resty-limit-traffic` - 限流
- `lua-resty-upstream-healthcheck` - 健康检查

## 相关链接

- 官网: https://openresty.org/
- 文档: https://openresty.org/en/installation.html
- GitHub: https://github.com/openresty/openresty
- 邮件列表: https://groups.google.com/group/openresty