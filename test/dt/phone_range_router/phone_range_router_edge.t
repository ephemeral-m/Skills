# Test::Nginx 测试用例 - phone_range_router 边界条件
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * (blocks() * 4);
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 边界值测试 - 区间最小值
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
phone-number: 13800000000

--- response_headers
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]

=== TEST 2: 边界值测试 - 区间最大值
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
phone-number: 13899999999

--- response_headers
X-Upstream: backend_a

--- response_body
upstream: backend_a

--- error_code: 200
--- no_error_log
[error]

=== TEST 3: 边界值测试 - 小于区间最小值
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
phone-number: 13799999999

--- response_headers
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- no_error_log
[error]

=== TEST 4: 边界值测试 - 大于区间最大值
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
phone-number: 13900000000

--- response_headers
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- no_error_log
[error]

=== TEST 5: 多区间重叠测试 - 按min排序后匹配第一个
--- http_config
    lua_package_path "$prefix/../../../../plugins/?.lua;;";

    init_by_lua_block {
        local router = require "phone_range_router.phone_range_router"
        local ok, err = router.init_worker({
            ranges = {
                { min = "13800000000", max = "13999999999", upstream = "wide_range" },
                { min = "13810000000", max = "13820000000", upstream = "narrow_range" }
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
phone-number: 13815000000

--- response_headers
X-Upstream: wide_range

--- response_body
upstream: wide_range

--- error_code: 200
--- no_error_log
[error]

=== TEST 6: 无效手机号格式 - 长度不足11位
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
phone-number: 1381234567

--- response_headers
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- error_log
invalid phone format

=== TEST 7: 无效手机号格式 - 长度超过11位
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
phone-number: 138123456789

--- response_headers
X-Upstream: default_backend

--- response_body
upstream: default_backend

--- error_code: 200
--- error_log
invalid phone format