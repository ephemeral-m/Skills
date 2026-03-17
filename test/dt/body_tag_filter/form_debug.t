# Test::Nginx 测试用例 - form-urlencoded 调试
use lib 'lib';
use Test::Nginx::Socket::Lua;

plan tests => repeat_each() * 2;
no_shuffle();
run_tests();

__DATA__

=== TEST 1: 调试 form-urlencoded 解析
--- http_config
    lua_package_path "$prefix/../../../../src/lua-plugins/?.lua;;";

--- config
    lua_need_request_body on;
    client_body_buffer_size 1m;

    location /test {
        content_by_lua_block {
            ngx.req.read_body()
            local body = ngx.req.get_body_data()
            local ct = ngx.req.get_headers()["Content-Type"]

            ngx.say("body: ", body or "nil")
            ngx.say("content_type: ", ct or "nil")

            -- 测试 form 解析
            local m = ngx.re.match(body, "gray=([^&]*)", "jo")
            if m then
                ngx.say("matched: ", m[1])
            else
                ngx.say("no match")
            end
        }
    }

--- request
POST /test
gray=true&name=test

--- more_headers
Content-Type: application/x-www-form-urlencoded

--- response_body_like
matched: true