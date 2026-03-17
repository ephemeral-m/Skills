# Test::Nginx 测试用例 - body_tag_filter 基础功能
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 9 * 2 + 1;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: JSON 请求体 - 拦截匹配的标签值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true", "1"},
            reject_code = 403,
            reject_message = "Gray traffic blocked"
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
{"gray": "true", "data": "test"}

--- more_headers
Content-Type: application/json

--- error_code: 403
--- response_body_like
Gray traffic blocked

=== TEST 2: JSON 请求体 - 放行不匹配的标签值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true", "1"},
            reject_code = 403,
            reject_message = "Gray traffic blocked"
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
{"gray": "false", "data": "test"}

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed

=== TEST 3: Form-urlencoded 请求体 - 拦截匹配的标签值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"},
            reject_code = 403,
            reject_message = "Gray traffic blocked"
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
gray=true&name=test

--- more_headers
Content-Type: application/x-www-form-urlencoded

--- error_code: 403
--- response_body_like
Gray traffic blocked

=== TEST 4: 白名单模式 - 允许匹配的标签值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "env",
            allow_values = {"production", "prod"},
            reject_code = 403,
            reject_message = "Access denied"
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
{"env": "production", "data": "test"}

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed

=== TEST 5: 白名单模式 - 拦截不在白名单的标签值
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "env",
            allow_values = {"production", "prod"},
            reject_code = 403,
            reject_message = "Access denied"
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
{"env": "staging", "data": "test"}

--- more_headers
Content-Type: application/json

--- error_code: 403
--- response_body_like
Access denied

=== TEST 6: GET 请求 - 无请求体，直接放行
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
GET /test

--- error_code: 200
--- response_body_like
passed

=== TEST 7: 自定义错误码
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

    init_by_lua_block {
        local filter = require "body_tag_filter.body_tag_filter"
        filter.init_worker({
            tag_field = "gray",
            block_values = {"true"},
            reject_code = 503,
            reject_message = "Service temporarily unavailable"
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

--- error_code: 503
--- response_body_like
Service temporarily unavailable

=== TEST 8: 请求体无标签字段 - 放行
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
{"data": "test", "name": "example"}

--- more_headers
Content-Type: application/json

--- error_code: 200
--- response_body_like
passed

=== TEST 9: 响应头包含标签值
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
{"gray": "false"}

--- more_headers
Content-Type: application/json

--- response_headers
X-Tag-Value: false
--- error_code: 200
--- response_body_like
passed