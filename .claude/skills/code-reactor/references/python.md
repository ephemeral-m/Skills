# Python 重构指南

## 目录
- [Python 特定重构技术](#python-特定重构技术)
- [代码示例](#代码示例)
- [工具推荐](#工具推荐)
- [常见陷阱](#常见陷阱)

---

## Python 特定重构技术

### 1. 用字典替换条件分支

```python
# 重构前
def get_discount(customer_type):
    if customer_type == 'regular':
        return 0.05
    elif customer_type == 'silver':
        return 0.10
    elif customer_type == 'gold':
        return 0.15
    elif customer_type == 'platinum':
        return 0.20
    else:
        return 0.0

# 重构后
DISCOUNT_RATES = {
    'regular': 0.05,
    'silver': 0.10,
    'gold': 0.15,
    'platinum': 0.20,
}

def get_discount(customer_type):
    return DISCOUNT_RATES.get(customer_type, 0.0)
```

### 2. 用 dataclass 替换普通类

```python
# 重构前
class User:
    def __init__(self, name, age, email):
        self.name = name
        self.age = age
        self.email = email

    def __repr__(self):
        return f"User({self.name}, {self.age}, {self.email})"

    def __eq__(self, other):
        return (self.name, self.age, self.email) == (other.name, other.age, other.email)

# 重构后
from dataclasses import dataclass

@dataclass
class User:
    name: str
    age: int
    email: str
```

### 3. 用列表推导/生成器替换循环

```python
# 重构前
def get_active_emails(users):
    result = []
    for user in users:
        if user.is_active:
            result.append(user.email)
    return result

# 重构后
def get_active_emails(users):
    return [user.email for user in users if user.is_active]
```

### 4. 用上下文管理器管理资源

```python
# 重构前
def process_file(path):
    f = open(path, 'r')
    try:
        data = f.read()
        process(data)
    finally:
        f.close()

# 重构后
def process_file(path):
    with open(path, 'r') as f:
        data = f.read()
        process(data)
```

### 5. 用类型注解提高可读性

```python
# 重构前
def calculate_total(items, tax_rate):
    total = sum(item['price'] * item['quantity'] for item in items)
    return total * (1 + tax_rate)

# 重构后
from typing import TypedDict

class Item(TypedDict):
    price: float
    quantity: int

def calculate_total(items: list[Item], tax_rate: float) -> float:
    total = sum(item['price'] * item['quantity'] for item in items)
    return total * (1 + tax_rate)
```

### 6. 用 walrus 操作符简化

```python
# 重构前
def find_and_process(data):
    match = pattern.search(data)
    if match:
        return process_match(match)
    return None

# 重构后 (Python 3.8+)
def find_and_process(data):
    if match := pattern.search(data):
        return process_match(match)
    return None
```

### 7. 用 match-case 替换复杂条件 (Python 3.10+)

```python
# 重构前
def handle_event(event):
    if event['type'] == 'click':
        if 'x' in event and 'y' in event:
            handle_click(event['x'], event['y'])
    elif event['type'] == 'keypress':
        if 'key' in event:
            handle_key(event['key'])

# 重构后
def handle_event(event):
    match event:
        case {'type': 'click', 'x': x, 'y': y}:
            handle_click(x, y)
        case {'type': 'keypress', 'key': key}:
            handle_key(key)
```

---

## 工具推荐

```bash
# 代码格式化
pip install black
black .

# 导入排序
pip install isort
isort .

# Lint 检查
pip install ruff
ruff check .

# 类型检查
pip install mypy
mypy .

# 自动重构
pip install bowler
# 用于大规模重构
```

---

## 常见陷阱

### 可变默认参数
```python
# 错误
def add_item(item, items=[]):
    items.append(item)
    return items

# 正确
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### 循环变量泄漏
```python
# 危险 - i 在循环后仍存在
for i in range(10):
    process(i)
print(i)  # 9

# 更安全 - 使用生成器表达式
any(process(i) for i in range(10))
```

### 过度使用 lambda
```python
# 难以阅读
sorted(users, key=lambda u: u.profile.settings.preferences.theme)

# 更清晰
def get_theme(user):
    return user.profile.settings.preferences.theme

sorted(users, key=get_theme)
```