# Test::Nginx 测试用例 - phone_range_router 配置验证
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 22;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 配置验证 - 缺少 upstream 字段
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        echo "test";
    }

--- request
GET /test

--- error_log
upstream required

=== TEST 2: 配置验证 - 无效的 min 格式
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "invalid", max = "13899999999", upstream = "backend_a" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        echo "test";
    }

--- request
GET /test

--- error_log
invalid range

=== TEST 3: 配置验证 - min 大于 max
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13900000000", max = "13800000000", upstream = "backend_a" }
            },
            default_upstream = "default_backend"
        })
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        echo "test";
    }

--- request
GET /test

--- error_log
min > max

=== TEST 4: 配置验证 - 空 data 参数
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker(nil)
        if not ok then
            ngx.log(ngx.ERR, "init_worker failed: ", err)
        end
    }

--- config
    location /test {
        echo "test";
    }

--- request
GET /test

--- error_log
data is nil

=== TEST 5: 配置验证 - 空 ranges 使用默认路由
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {},
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
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 自定义 header_name 配置
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13899999999", upstream = "backend_a" }
            },
            default_upstream = "default_backend",
            header_name = "x-phone"
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
x-phone: 13812345678

--- response_headers
X-Phone: 13812345678
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]

=== TEST 7: 多个手机号请求头 - 使用第一个
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
phone-number: 13987654321

--- response_headers
X-Phone: 13812345678
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]