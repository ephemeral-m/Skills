# Test::Nginx 测试用例 - gray_router 配置验证
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 19;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 配置验证 - 无效的 status 类型
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        local ok, err = plugin.init_worker({
            response = {
                status = "invalid"
            }
        })
        if not ok then
            ngx.log(ngx.ERR, "expected error: ", err)
        end
    }

--- config
    location /t {
        echo "OK";
    }

--- request
GET /t
--- error_log
response.status must be a number

=== TEST 2: 配置验证 - 无效的 tag_pattern 类型
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        local ok, err = plugin.init_worker({
            tag_pattern = 123
        })
        if not ok then
            ngx.log(ngx.ERR, "expected error: ", err)
        end
    }

--- config
    location /t {
        echo "OK";
    }

--- request
GET /t
--- error_log
tag_pattern must be a string

=== TEST 3: 配置验证 - 空配置使用默认值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker()
    }

--- config
    location /api {
        lua_need_request_body on;
        client_body_buffer_size 1m;

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend"}';
    }

--- request
POST /api
gray=true
--- response_body_like
^$
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: 配置验证 - 自定义标签模式
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "version=beta",
            response = {
                status = 200,
                body = '{"version": "beta"}'
            }
        })
    }

--- config
    location /api {
        lua_need_request_body on;
        client_body_buffer_size 1m;

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend"}';
    }

--- request
POST /api
env=prod&version=beta
--- response_body
{"version": "beta"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: 配置验证 - 自定义标签模式不匹配
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "version=beta",
            response = {
                status = 200,
                body = '{"version": "beta"}'
            }
        })
    }

--- config
    location /api {
        lua_need_request_body on;
        client_body_buffer_size 1m;

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend"}';
    }

--- request
POST /api
version=alpha
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 配置验证 - 多个响应头
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                headers = {
                    ["X-Gray"] = "true",
                    ["X-Gray-Version"] = "v1.0.0",
                    ["X-Custom-Header"] = "custom-value"
                },
                body = '{"code": 0}'
            }
        })
    }

--- config
    location /api {
        lua_need_request_body on;
        client_body_buffer_size 1m;

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend"}';
    }

--- request
POST /api
gray=true
--- response_headers
X-Gray: true
X-Gray-Version: v1.0.0
X-Custom-Header: custom-value
--- response_body
{"code": 0}
--- error_code: 200
--- no_error_log
[error]