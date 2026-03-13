# Shell/Bash 代码审查指南

## 常见问题检查

### 安全问题

```bash
# ❌ 命令注入
eval "$user_input"
rm -rf "$user_input"

# ✅ 验证输入
case "$user_input" in
    *[!a-zA-Z0-9_]*) echo "Invalid input"; exit 1 ;;
esac

# ❌ 不安全地使用 sudo
sudo rm -rf "$USER_INPUT"

# ✅ 限制 sudo 权限
# 在 sudoers 中配置具体的允许命令

# ❌ 未引用变量
rm $file  # 文件名含空格会出错

# ✅ 引用变量
rm "$file"
```

### 错误处理

```bash
# ❌ 忽略错误
cd "$dir"
rm *  # 如果 cd 失败，删除错误目录

# ✅ 检查错误
set -e  # 任何命令失败立即退出
cd "$dir" || exit 1
rm *

# ❌ 未处理管道错误
command1 | command2  # 只检查 command2 的退出状态

# ✅ 使用 pipefail
set -o pipefail
command1 | command2
```

### 竞态条件

```bash
# ❌ TOCTOU 竞态
if [ ! -f "$lock" ]; then
    touch "$lock"  # 检查和创建之间可能被其他进程干扰
    do_work
    rm "$lock"
fi

# ✅ 使用 flock
(
    flock -x 9 || exit 1
    do_work
) 9>"$lock"

# ❌ 不安全的临时文件
tmp="/tmp/myapp.$$"
echo "data" > "$tmp"  # 可预测的文件名，可能被劫持

# ✅ 安全的临时文件
tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT
echo "data" > "$tmp"
```

### 变量和引用

```bash
# ❌ 未引用变量
for file in $(ls); do
    process $file
done

# ✅ 正确引用
for file in *; do
    process "$file"
done

# ❌ 未引用变量导致词法拆分
args=$@
process $args  # 空格会被拆分

# ✅ 正确引用
args=("$@")
process "${args[@]}"

# ❌ 单引号阻止变量展开
echo '$HOME'  # 输出 $HOME

# ✅ 双引号允许变量展开
echo "$HOME"  # 输出实际路径
```

---

## Shell 特有检查点

### 脚本头部

```bash
# ❌ 缺少 shebang 或 bash 特性
#!/bin/sh
array=(1 2 3)  # 在 POSIX sh 中不工作

# ✅ 明确使用 bash
#!/usr/bin/env bash
set -euo pipefail

# ❌ 硬编码路径
#!/bin/bash

# ✅ 使用 env 提高可移植性
#!/usr/bin/env bash
```

### 函数定义

```bash
# ❌ 非标准函数定义
function foo {
    # ...
}

# ✅ POSIX 兼容
foo() {
    # ...
}

# ❌ 全局变量污染
process() {
    result=$(command)
}

# ✅ 使用 local
process() {
    local result
    result=$(command)
}
```

### 条件判断

```bash
# ❌ 使用已废弃的 test
[ $x == "foo" ]

# ✅ 使用 [[ ]]
[[ "$x" == "foo" ]]

# ❌ 字符串比较不引用
[ $status = "active" ]

# ✅ 引用变量
[[ "$status" == "active" ]]
```

---

## 检查清单

```
□ 所有变量都用双引号引用
□ 使用 set -euo pipefail
□ 错误时正确退出
□ 使用 flock 避免竞态条件
□ 使用 mktemp 创建临时文件
□ 使用 trap 清理资源
□ 函数内使用 local 变量
□ 使用 [[ ]] 替代 [ ]
□ 避免使用 eval
□ 检查命令是否存在
□ 使用 for file in * 替代 $(ls)
□ shebang 使用 #!/usr/bin/env bash
```

---

## 工具推荐

```bash
# 语法检查
shellcheck script.sh

# 格式化
shfmt -w script.sh

# 调试
bash -n script.sh    # 语法检查
bash -x script.sh    # 执行跟踪
bash -c 'set -o'     # 查看选项
```