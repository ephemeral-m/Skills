# Shell/Bash 重构指南

## 目录
- [特定重构技术](#特定重构技术)
- [代码示例](#代码示例)
- [工具推荐](#工具推荐)
- [常见陷阱](#常见陷阱)

---

## 特定重构技术

### 1. 用函数提取重复逻辑

```bash
# 重构前
echo "处理文件 A..."
FILE_A="data_a.txt"
if [ -f "$FILE_A" ]; then
    wc -l "$FILE_A"
    md5sum "$FILE_A"
fi

echo "处理文件 B..."
FILE_B="data_b.txt"
if [ -f "$FILE_B" ]; then
    wc -l "$FILE_B"
    md5sum "$FILE_B"
fi

# 重构后
process_file() {
    local file="$1"
    echo "处理文件 $file..."
    if [ -f "$file" ]; then
        wc -l "$file"
        md5sum "$file"
    fi
}

process_file "data_a.txt"
process_file "data_b.txt"
```

### 2. 用数组替代多个变量

```bash
# 重构前
FILE1="config.json"
FILE2="settings.json"
FILE3="database.json"

process "$FILE1"
process "$FILE2"
process "$FILE3"

# 重构后
FILES=("config.json" "settings.json" "database.json")

for file in "${FILES[@]}"; do
    process "$file"
done
```

### 3. 用 case 替代多个 if-elif

```bash
# 重构前
if [ "$action" = "start" ]; then
    start_service
elif [ "$action" = "stop" ]; then
    stop_service
elif [ "$action" = "restart" ]; then
    stop_service
    start_service
elif [ "$action" = "status" ]; then
    show_status
else
    echo "Unknown action"
    exit 1
fi

# 重构后
case "$action" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        stop_service
        start_service
        ;;
    status)
        show_status
        ;;
    *)
        echo "未知操作: $action"
        exit 1
        ;;
esac
```

### 4. 用 set -e 和 trap 管理错误

```bash
# 重构前
command1 || exit 1
command2 || exit 1
command3 || exit 1
cleanup

# 重构后
set -e  # 任何命令失败立即退出

cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

command1
command2
command3
# cleanup 自动执行
```

### 5. 用参数扩展简化字符串操作

```bash
# 重构前
filename="/path/to/file.txt"
basename=$(echo "$filename" | xargs basename)
extension=$(echo "$filename" | awk -F. '{print $NF}')
dirname=$(echo "$filename" | xargs dirname)

# 重构后
filename="/path/to/file.txt"
basename="${filename##*/}"      # file.txt
extension="${filename##*.}"     # txt
dirname="${filename%/*}"        # /path/to
namenoext="${filename%.*}"      # /path/to/file
```

### 6. 用 [[ ]] 替代 [ ]

```bash
# 重构前 (传统 test)
[ -f "$file" ] && [ "$status" = "active" ]

# 重构后 (现代 bash)
[[ -f "$file" && "$status" == "active" ]]
```

### 7. 用 here-doc 处理多行文本

```bash
# 重构前
echo "line1" > config.txt
echo "line2" >> config.txt
echo "line3" >> config.txt

# 重构后
cat > config.txt << 'EOF'
line1
line2
line3
EOF
```

### 8. 用 getopts 解析参数

```bash
# 重构前
while [ $# -gt 0 ]; do
    if [ "$1" = "-h" ]; then
        show_help
        exit 0
    elif [ "$1" = "-v" ]; then
        VERBOSE=1
    elif [ "$1" = "-f" ]; then
        shift
        FILE="$1"
    fi
    shift
done

# 重构后
VERBOSE=0
FILE=""

while getopts "hvf:" opt; do
    case $opt in
        h) show_help; exit 0 ;;
        v) VERBOSE=1 ;;
        f) FILE="$OPTARG" ;;
        ?) exit 1 ;;
    esac
done
```

---

## 工具推荐

```bash
# Shell 语法检查
shellcheck script.sh

# 格式化
shfmt -w script.sh

# 调试
bash -x script.sh    # 显示执行的命令
bash -n script.sh    # 仅语法检查
```

---

## 常见陷阱

### 未引用变量

```bash
# 错误 - 文件名含空格会出错
for file in $(ls); do
    rm $file
done

# 正确
for file in *; do
    rm "$file"
done
```

### 误用 ls

```bash
# 错误 - 无法处理含空格文件名
for file in $(ls); do
    process "$file"
done

# 正确
for file in *; do
    process "$file"
done
```

### 忘记检查命令失败

```bash
# 错误
cd "$directory"
rm *  # 如果 cd 失败，会删除错误目录的内容

# 正确
cd "$directory" || exit 1
rm *

# 或使用 set -e
set -e
cd "$directory"
rm *
```

### 竞态条件

```bash
# 错误
if [ ! -f "$LOCK" ]; then
    touch "$LOCK"  # 检查和创建之间可能被其他进程干扰
    do_work
    rm "$LOCK"
fi

# 正确 - 使用 flock
(
    flock -x 9 || exit 1
    do_work
) 9>"$LOCK"
```