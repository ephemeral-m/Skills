# Test::Nginx 测试用例 - body_tag_filter 边界条件
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 8;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 空请求体
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"}
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

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed

=== TEST 2: 不支持的 Content-Type
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"}
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
gray=true

--- more_headers
Content-Type: application/xml

--- error_code: 200
--- response_body_like
passed

=== TEST 3: URL 编码的表单值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"}
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
gray=true&name=test%20user

--- more_headers
Content-Type: application/x-www-form-urlencoded

--- error_code: 403
--- response_body_like
Request blocked

=== TEST 4: Content-Type 带字符集
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"}
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
Content-Type: application/json; charset=utf-8

--- error_code: 403
--- response_body_like
Request blocked