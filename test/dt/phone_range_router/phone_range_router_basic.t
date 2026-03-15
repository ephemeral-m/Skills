# Test::Nginx 测试用例 - phone_range_router 基础功能
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 24;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 基本路由 - 手机号匹配第一个区间
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" },
                { min = "13900000000", max = "13999999999", upstream = "backend_b" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        set $upstream '';
        access_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.prerouting()
            router.postrouting()
        }
        header_filter_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.header_filter()
        }
        echo "upstream: $upstream";
    }

--- request
GET /test

--- more_headers
phone-number: 13812345678

--- response_headers
X-Phone: 13812345678
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]

=== TEST 2: 基本路由 - 手机号匹配第二个区间
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" },
                { min = "13900000000", max = "13999999999", upstream = "backend_b" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        set $upstream '';
        access_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.prerouting()
            router.postrouting()
        }
        header_filter_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.header_filter()
        }
        echo "upstream: $upstream";
    }

--- request
GET /test

--- more_headers
phone-number: 13987654321

--- response_headers
X-Phone: 13987654321
X-Upstream: backend_b

--- response_body
upstream: backend_b

--- error_code: 200
--- no_error_log
[error]

=== TEST 3: 默认路由 - 手机号不在任何区间
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" },
                { min = "13900000000", max = "13999999999", upstream = "backend_b" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        set $upstream '';
        access_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.prerouting()
            router.postrouting()
        }
        header_filter_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.header_filter()
        }
        echo "upstream: $upstream";
    }

--- request
GET /test

--- more_headers
phone-number: 15012345678

--- response_headers
X-Phone: 15012345678
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- no_error_log
[error]

=== TEST 4: 无手机号请求头 - 使用默认路由
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        set $upstream '';
        access_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.prerouting()
            router.postrouting()
        }
        header_filter_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.header_filter()
        }
        echo "upstream: $upstream";
    }

--- request
GET /test

--- response_headers
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- no_error_log
[error]

=== TEST 5: 手机号带格式 - 包含空格和横线
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        set $upstream '';
        access_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.prerouting()
            router.postrouting()
        }
        header_filter_by_lua_block {
            local router = require "phone_range_router.phone_range_router"
            router.header_filter()
        }
        echo "upstream: $upstream";
    }

--- request
GET /test

--- more_headers
phone-number: 138-1234-5678

--- response_headers
X-Phone: 138-1234-5678
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]