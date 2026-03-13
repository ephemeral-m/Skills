# Python 代码审查指南

## 常见问题检查

### 安全问题

```python
# ❌ SQL 注入
cursor.execute(f"SELECT * FROM users WHERE id = {user_id}")

# ✅ 参数化查询
cursor.execute("SELECT * FROM users WHERE id = %s", (user_id,))

# ❌ 命令注入
os.system(f"rm {user_input}")

# ✅ 安全替代
subprocess.run(["rm", path], check=True)

# ❌ 不安全的反序列化
pickle.loads(user_data)

# ✅ 安全替代
json.loads(user_data)
```

### 性能问题

```python
# ❌ N+1 查询
for user in users:
    profile = get_profile(user.id)  # 每次循环都查询

# ✅ 批量查询
user_ids = [u.id for u in users]
profiles = get_profiles(user_ids)

# ❌ 列表作为队列（O(n)）
items = []
items.pop(0)  # 低效

# ✅ 使用 collections.deque（O(1)）
from collections import deque
items = deque()
items.popleft()

# ❌ 字符串拼接
result = ""
for s in strings:
    result += s  # 每次创建新字符串

# ✅ 使用 join
result = "".join(strings)
```

### 代码质量问题

```python
# ❌ 可变默认参数
def add_item(item, items=[]):
    items.append(item)
    return items

# ✅ 使用 None
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items

# ❌ 裸 except
try:
    do_something()
except:
    pass  # 吞掉所有异常

# ✅ 具体异常
try:
    do_something()
except ValueError as e:
    logger.error(f"处理失败: {e}")
    raise

# ❌ 忽略返回值
json.loads(data)  # 结果未使用

# ✅ 使用返回值
result = json.loads(data)
```

---

## Python 特有检查点

### 类型注解

```python
# ❌ 缺少类型注解
def process(data):
    return data.value

# ✅ 添加类型注解
from typing import Optional

def process(data: Data) -> Optional[str]:
    return data.value
```

### 异步代码

```python
# ❌ 在异步函数中使用阻塞调用
async def fetch_data():
    time.sleep(1)  # 阻塞事件循环

# ✅ 使用异步替代
async def fetch_data():
    await asyncio.sleep(1)
```

### 资源管理

```python
# ❌ 手动管理资源
f = open('file.txt')
try:
    data = f.read()
finally:
    f.close()

# ✅ 使用上下文管理器
with open('file.txt') as f:
    data = f.read()
```

---

## 检查清单

```
□ 使用参数化查询防止 SQL 注入
□ 避免使用 pickle 反序列化不受信任的数据
□ 可变默认参数使用 None 替代
□ 异常处理具体化，不使用裸 except
□ 使用 with 语句管理资源
□ 类型注解是否完整
□ 异步代码中避免阻塞调用
□ 避免在循环中进行数据库查询
□ 使用 join 而非 + 拼接字符串
□ 使用 deque 替代列表作为队列
```

---

## 工具推荐

```bash
# Lint
ruff check .
pylint src/

# 类型检查
mypy src/

# 安全检查
bandit -r src/
safety check

# 格式化
black .
isort .
```