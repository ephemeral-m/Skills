# Test::Nginx 测试用例 - gray_router 边界条件
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 27;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 边界条件 - 空请求体
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
POST /api
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 2: 边界条件 - 请求体为 null
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
POST /api
null
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 3: 边界条件 - gray=true 在字符串值中
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
POST /api
message=the+text+contains+gray=true+as+substring
--- response_body
{"gray": true}
--- error_code: 200
--- no_error_log
[error]

=== TEST 4: 边界条件 - gray=false 不触发灰度
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
POST /api
gray=false
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 5: 边界条件 - 大小写敏感测试
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
POST /api
GRAY=true
--- response_body
{"from": "backend"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 边界条件 - 特殊字符在标签中
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local plugin = require "gray_router.gray_router"
        plugin.init_worker({
            tag_pattern = "env=test-v1.0",
            response = {
                status = 200,
                body = '{"env": "test"}'
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
env=test-v1.0
--- response_body
{"env": "test"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 7: 边界条件 - DELETE 请求不检查请求体
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

        rewrite_by_lua_block {
            require("gray_router.gray_router").prerouting()
        }

        access_by_lua_block {
            require("gray_router.gray_router").postrouting()
        }

        proxy_pass http://127.0.0.1:$TEST_NGINX_SERVER_PORT/backend;
    }

    location /backend {
        echo '{"from": "backend", "method": "DELETE"}';
    }

--- request
DELETE /api
--- response_body
{"from": "backend", "method": "DELETE"}
--- error_code: 200
--- no_error_log
[error]

=== TEST 8: 边界条件 - 嵌套值中的 gray=true
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
POST /api
data={"nested":"gray=true"}
--- response_body
{"gray": true}
--- error_code: 200
--- no_error_log
[error]

=== TEST 9: 边界条件 - 数组中的 gray=true
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
POST /api
items=["gray=true","other"]
--- response_body
{"gray": true}
--- error_code: 200
--- no_error_log
[error]