# Test::Nginx 测试用例 - gray_router 基础功能
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 28;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 插件加载 - 默认配置
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        local ok, err = plugin.init_worker()
        if not ok then
            ngx.log(ngx.ERR, "init failed: ", err)
        end
    }

--- config
    location /t {
        echo "OK";
    }

--- request
GET /t
--- response_body
OK
--- no_error_log
[error]

=== TEST 2: 插件加载 - 自定义配置
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        local ok, err = plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                headers = {
                    ["X-Gray"] = "true"
                },
                body = '{"code": 0}'
            }
        })
        if not ok then
            ngx.log(ngx.ERR, "init failed: ", err)
        end
    }

--- config
    location /t {
        echo "OK";
    }

--- request
GET /t
--- response_body
OK
--- no_error_log
[error]

=== TEST 3: POST 表单格式包含 gray=true - 返回灰度响应
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
                    ["Content-Type"] = "application/json"
                },
                body = '{"code": 0, "message": "gray response"}'
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
name=test&gray=true&value=123
--- response_headers
X-Gray: true
--- response_body
{"code": 0, "message": "gray response"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: POST 表单格式不包含 gray=true - 转发到后端
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                body = '{"code": 0, "message": "gray response"}'
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
name=test&gray=false
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: GET 请求 - 直接转发到后端
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                body = '{"code": 0}'
            }
        })
    }

--- config
    location /api {
        lua_need_request_body on;

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend", "method": "GET"}';
    }

--- request
GET /api
--- response_body
{"from": "backend", "method": "GET"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 自定义状态码
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 201,
                body = '{"created": true}'
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
--- response_body
{"created": true}
--- error_code: 201
--- no_error_log
[error]

=== TEST 7: PUT 请求检查请求体
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "gray=true",
            response = {
                status = 200,
                body = '{"gray": true}'
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
PUT /api
data=update&gray=true
--- response_body
{"gray": true}
--- error_code: 200
--- no_error_log
[error]

=== TEST 8: 多个响应头
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