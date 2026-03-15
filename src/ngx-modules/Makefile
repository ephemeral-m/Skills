# Nginx C 模块 Makefile
# 支持静态编译和动态模块编译

# OpenResty 源码路径
OPENRESTY_SRC=../openresty
NGINX_SRC=$(OPENRESTY_SRC)/bundle/nginx-*

# 编译器设置
CC=gcc
CFLAGS=-Wall -Wextra -O2 -fPIC
INCLUDES=-I$(NGINX_SRC)/src/core \
         -I$(NGINX_SRC)/src/event \
         -I$(NGINX_SRC)/src/event/modules \
         -I$(NGINX_SRC)/src/os/unix \
         -I$(NGINX_SRC)/src/http \
         -I$(NGINX_SRC)/src/http/modules \
         -I$(OPENRESTY_SRC)/bundle/ngx_lua-*/src \
         -I$(OPENRESTY_SRC)/build

# 源文件
SRCS=src/ngx_http_hello_module.c
OBJS=$(SRCS:.c=.o)

# 目标
TARGET=ngx_http_hello_module.so

.PHONY: all clean static dynamic test

all: dynamic

# 编译动态模块
dynamic: $(TARGET)

$(TARGET): $(OBJS)
	$(CC) -shared -o $@ $^

%.o: %.c
	$(CC) $(CFLAGS) $(INCLUDES) -c $< -o $@

# 静态编译到 OpenResty (需要重新编译 OpenResty)
static:
	cd $(OPENRESTY_SRC) && \
	./configure --add-module=$(PWD) && \
	make && make install

# 清理
clean:
	rm -f $(OBJS) $(TARGET)

# 测试
test: dynamic
	@echo "Copy module to nginx modules directory and test"