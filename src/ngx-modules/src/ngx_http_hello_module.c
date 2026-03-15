/*
 * ngx_http_hello_module.c
 * 示例 Nginx C 模块 - 返回简单问候消息
 */

#include <ngx_config.h>
#include <ngx_core.h>
#include <ngx_http.h>

/* 模块配置结构 */
typedef struct {
    ngx_str_t  name;
    ngx_int_t  count;
} ngx_http_hello_loc_conf_t;

/* 函数声明 */
static ngx_int_t ngx_http_hello_handler(ngx_http_request_t *r);
static char *ngx_http_hello_set(ngx_conf_t *cf, ngx_command_t *cmd, void *conf);
static void *ngx_http_hello_create_loc_conf(ngx_conf_t *cf);
static char *ngx_http_hello_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child);

/* 模块指令 */
static ngx_command_t ngx_http_hello_commands[] = {
    { ngx_string("hello"),
      NGX_HTTP_LOC_CONF|NGX_CONF_NOARGS,
      ngx_http_hello_set,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_hello_loc_conf_t, name),
      NULL },

    { ngx_string("hello_name"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_str_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_hello_loc_conf_t, name),
      NULL },

    { ngx_string("hello_count"),
      NGX_HTTP_MAIN_CONF|NGX_HTTP_SRV_CONF|NGX_HTTP_LOC_CONF|NGX_CONF_TAKE1,
      ngx_conf_set_num_slot,
      NGX_HTTP_LOC_CONF_OFFSET,
      offsetof(ngx_http_hello_loc_conf_t, count),
      NULL },

    ngx_null_command
};

/* 模块上下文 */
static ngx_http_module_t ngx_http_hello_module_ctx = {
    NULL,                               /* preconfiguration */
    NULL,                               /* postconfiguration */
    NULL,                               /* create main configuration */
    NULL,                               /* init main configuration */
    NULL,                               /* create server configuration */
    NULL,                               /* merge server configuration */
    ngx_http_hello_create_loc_conf,     /* create location configuration */
    ngx_http_hello_merge_loc_conf       /* merge location configuration */
};

/* 模块定义 */
ngx_module_t ngx_http_hello_module = {
    NGX_MODULE_V1,
    &ngx_http_hello_module_ctx,         /* module context */
    ngx_http_hello_commands,            /* module directives */
    NGX_HTTP_MODULE,                    /* module type */
    NULL,                               /* init master */
    NULL,                               /* init module */
    NULL,                               /* init process */
    NULL,                               /* init thread */
    NULL,                               /* exit thread */
    NULL,                               /* exit process */
    NULL,                               /* exit master */
    NGX_MODULE_V1_PADDING
};

/* 创建 location 配置 */
static void *
ngx_http_hello_create_loc_conf(ngx_conf_t *cf)
{
    ngx_http_hello_loc_conf_t *conf;

    conf = ngx_pcalloc(cf->pool, sizeof(ngx_http_hello_loc_conf_t));
    if (conf == NULL) {
        return NULL;
    }

    ngx_str_null(&conf->name);
    conf->count = NGX_CONF_UNSET;

    return conf;
}

/* 合并 location 配置 */
static char *
ngx_http_hello_merge_loc_conf(ngx_conf_t *cf, void *parent, void *child)
{
    ngx_http_hello_loc_conf_t *prev = parent;
    ngx_http_hello_loc_conf_t *conf = child;

    ngx_conf_merge_str_value(conf->name, prev->name, "World");
    ngx_conf_merge_value(conf->count, prev->count, 1);

    return NGX_CONF_OK;
}

/* 设置处理函数 */
static char *
ngx_http_hello_set(ngx_conf_t *cf, ngx_command_t *cmd, void *conf)
{
    ngx_http_core_loc_conf_t *clcf;

    clcf = ngx_http_conf_get_module_loc_conf(cf, ngx_http_core_module);
    clcf->handler = ngx_http_hello_handler;

    return NGX_CONF_OK;
}

/* 请求处理函数 */
static ngx_int_t
ngx_http_hello_handler(ngx_http_request_t *r)
{
    ngx_int_t                    rc;
    ngx_buf_t                   *b;
    ngx_chain_t                  out;
    ngx_http_hello_loc_conf_t   *hlcf;
    u_char                      *response;
    size_t                       len;

    /* 仅支持 GET 和 HEAD 方法 */
    if (!(r->method & (NGX_HTTP_GET|NGX_HTTP_HEAD))) {
        return NGX_HTTP_NOT_ALLOWED;
    }

    /* 丢弃请求体 */
    rc = ngx_http_discard_request_body(r);
    if (rc != NGX_OK) {
        return rc;
    }

    /* 获取配置 */
    hlcf = ngx_http_get_module_loc_conf(r, ngx_http_hello_module);

    /* 构建响应内容 */
    len = sizeof("Hello, !\nCount: \n") + hlcf->name.len + 32;
    response = ngx_pnalloc(r->pool, len);
    if (response == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    ngx_snprintf(response, len, "Hello, %V!\nCount: %d\n",
                 &hlcf->name, (int) hlcf->count);

    /* 设置响应头 */
    r->headers_out.status = NGX_HTTP_OK;
    r->headers_out.content_length_n = ngx_strlen(response);
    r->headers_out.content_type.len = sizeof("text/plain") - 1;
    r->headers_out.content_type.data = (u_char *) "text/plain";
    r->headers_out.content_type_len = r->headers_out.content_type.len;

    /* HEAD 请求只返回头部 */
    if (r->method == NGX_HTTP_HEAD) {
        rc = ngx_http_send_header(r);
        if (rc == NGX_ERROR || rc > NGX_OK || r->header_only) {
            return rc;
        }
    }

    /* 创建响应体缓冲区 */
    b = ngx_create_temp_buf(r->pool, ngx_strlen(response));
    if (b == NULL) {
        return NGX_HTTP_INTERNAL_SERVER_ERROR;
    }

    b->pos = response;
    b->last = response + ngx_strlen(response);
    b->last_buf = 1;
    b->last_in_chain = 1;

    out.buf = b;
    out.next = NULL;

    /* 发送响应头 */
    rc = ngx_http_send_header(r);
    if (rc == NGX_ERROR || rc > NGX_OK || r->header_only) {
        return rc;
    }

    /* 发送响应体 */
    return ngx_http_output_filter(r, &out);
}