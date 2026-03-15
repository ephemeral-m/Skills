# Nginx C 模块开发

本目录用于开发高性能 Nginx 原生模块。

## 目录结构

```
ngx-modules/
├── README.md                    # 本文件
├── Makefile                     # 编译配置
├── config                       # Nginx 模块配置脚本
├── src/                         # 模块源码
│   └── ngx_http_xxx_module.c    # HTTP 模块示例
├── include/                     # 头文件
├── test/                        # 测试文件
└── docs/                        # 文档
```

## 开发步骤

### 1. 创建模块骨架

```c
// src/ngx_http_xxx_module.c
#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

static ngx_int_t ngx_http_xxx_handler(ngx_http_request_t *r);
static char *ngx_http_xxx(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);

static ngx_command_t ngx_http_xxx_commands[] = {
    { ngx_string("xxx"),
      NGX_HTTP_LOC_CONF|NGX_CONF_NOARGS,
      ngx_http_xxx,
      NGX_HTTP_LOC_CONF_OFFSET,
      0,
      NULL },
    ngx_null_command
};

static ngx_http_module_t ngx_http_xxx_module_ctx = {
    NULL,                          /* preconfiguration */
    NULL,                          /* postconfiguration */
    NULL,                          /* create main configuration */
    NULL,                          /* init main configuration */
    NULL,                          /* create server configuration */
    NULL,                          /* merge server configuration */
    NULL,                          /* create location configuration */
    NULL                           /* merge location configuration */
};

ngx_module_t ngx_http_xxx_module = {
    NGX_MODULE_V1,
    &ngx_http_xxx_module_ctx,      /* module context */
    ngx_http_xxx_commands,         /* module directives */
    NGX_HTTP_MODULE,               /* module type */
    NULL,                          /* init master */
    NULL,                          /* init module */
    NULL,                          /* init process */
    NULL,                          /* init thread */
    NULL,                          /* exit thread */
    NULL,                          /* exit process */
    NULL,                          /* exit master */
    NGX_MODULE_V1_PADDING
};

static ngx_int_t
ngx_http_xxx_handler(ngx_http_request_t *r)
{
    ngx_int_t    rc;
    ngx_buf_t   *b;
    ngx_chain_t  out;

    // 设置响应头
    r->headers_out.status = NGX_HTTP_OK;
    r->headers_out.content_type.len = sizeof("text/plain") - 1;
    r->headers_out.content_type.data = (u_char *) "text/plain";

    // 创建响应体
    b = ngx_create_temp_buf(r->pool, sizeof("Hello from C module"));
    b->last = ngx_copy(b->pos, "Hello from C module",
                       sizeof("Hello from C module") - 1);
    b->last_buf = 1;

    out.buf = b;
    out.next = NULL;

    // 发送响应
    ngx_http_send_header(r);
    return ngx_http_output_filter(r, &out);
}

static char *
ngx_http_xxx(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_core_loc_conf_t *clcf;

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);
    clcf->handler = ngx_http_xxx_handler;

    return NGX_CONF_OK;
}
```

### 2. 创建 config 文件

```bash
# config
ngx_addon_name=ngx_http_xxx_module
HTTP_MODULES="$HTTP_MODULES ngx_http_xxx_module"
NGX_ADDON_SRCS="$NGX_ADDON_SRCS $ngx_addon_dir/src/ngx_http_xxx_module.c"
```

### 3. 编译模块

```bash
# 静态编译到 OpenResty
cd ../openresty
./configure --add-module=../ngx-modules
make
make install

# 或编译为动态模块
./configure --add-dynamic-module=../ngx-modules
make modules
```

### 4. 使用模块

```nginx
# nginx.conf
location /xxx {
    xxx;  # 调用模块指令
}
```

## 模块类型

### HTTP 模块
- 处理 HTTP 请求
- 实现 location handler
- 修改请求/响应

### Filter 模块
- 过滤响应头
- 过滤响应体
- 链式处理

### Upstream 模块
- 实现自定义后端协议
- 负载均衡器
- 健康检查

### Main 模块
- Nginx 核心功能扩展
- 事件处理
- 进程管理

## 参考资料

- [Nginx 模块开发指南](https://www.nginx.com/resources/wiki/extending/)
- [Emiller 的 Nginx 模块开发指南](https://www.evanmiller.org/nginx-modules-guide.html)
- [OpenResty 开发文档](https://openresty.org/cn/programming.html)