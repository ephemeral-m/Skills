# Test::Nginx 测试用例 - body_tag_filter 配置验证
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 6;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 默认配置 - 无参数初始化
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker()
    }

--- config
    lua_need_request_body on;
    client_body_buffer_size 1m;

    location /test {
        rewrite_by_lua_block {
            require("body_tag_filter.body_tag_filter").prerouting()
        }
        access_by_lua_block {
            require("body_tag_filter.body_tag_filter").postrouting()
        }
        header_filter_by_lua_block {
            require("body_tag_filter.body_tag_filter").header_filter()
        }
        echo "passed";
    }

--- request
POST /test
{"gray": "true"}

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed

=== TEST 2: 自定义标签字段名
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "status",
            block_values = {"blocked"}
        })
    }

--- config
    lua_need_request_body on;
    client_body_buffer_size 1m;

    location /test {
        rewrite_by_lua_block {
            require("body_tag_filter.body_tag_filter").prerouting()
        }
        access_by_lua_block {
            require("body_tag_filter.body_tag_filter").postrouting()
        }
        header_filter_by_lua_block {
            require("body_tag_filter.body_tag_filter").header_filter()
        }
        echo "passed";
    }

--- request
POST /test
{"status": "blocked", "data": "test"}

--- more_headers
Content-Type: application/json

--- error_code: 403
--- response_body_like
Request blocked

=== TEST 3: 白名单优先级高于黑名单
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true", "1"},
            allow_values = {"true"},
            reject_code = 403,
            reject_message = "Blocked"
        })
    }

--- config
    lua_need_request_body on;
    client_body_buffer_size 1m;

    location /test {
        rewrite_by_lua_block {
            require("body_tag_filter.body_tag_filter").prerouting()
        }
        access_by_lua_block {
            require("body_tag_filter.body_tag_filter").postrouting()
        }
        header_filter_by_lua_block {
            require("body_tag_filter.body_tag_filter").header_filter()
        }
        echo "passed";
    }

--- request
POST /test
{"gray": "true"}

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed