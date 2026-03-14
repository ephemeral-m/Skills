---
name: code-reactor
description: 通过系统性重构技术（提取函数、消除重复、简化条件、应用设计模式）改善代码结构、可读性和可维护性，但不改变外部行为。当用户需要重构代码、减少技术债务、消除重复、简化复杂逻辑、应用设计模式时使用此 skill。
---

# 代码重构

在不改变行为的前提下改善代码结构。

## 核心原则

1. **行为保持** - 重构绝不改变代码做什么，只改变怎么做
2. **小步前进** - 做微小变更，每步后测试
3. **测试先行** - 重构前确保有全面的测试
4. **一次一事** - 不要混合重构和功能添加

## 重构触发条件

- 函数超过 ~50 行
- 条件嵌套过深（>3 层）
- 重复代码（复制粘贴编程）
- 变量名不清晰
- 函数参数超过 3-4 个
- 类做太多事情（上帝类）

## 重构流程

```
1. 识别异味或改进机会
2. 确保测试存在且通过
3. 做一个小重构变更
4. 运行测试 - 必须通过
5. 重复直到满意
6. 代码审查
```

## 常用重构技术

### 提取函数

将长函数拆分为职责单一的小函数。

### 替换魔法数字

```python
# 重构前
if age >= 18: ...

# 重构后
ADULT_AGE = 18
if age >= ADULT_AGE: ...
```

### 卫语句替换嵌套条件

```python
# 重构前
def process(data):
    if data:
        if data.valid:
            return do_work(data)
    return None

# 重构后
def process(data):
    if not data: return None
    if not data.valid: return None
    return do_work(data)
```

### 合并重复代码

将相同逻辑抽取为共享函数。

### 删除死代码

移除注释掉的代码、未使用的变量和函数。

## 常见陷阱

| 陷阱 | 解决方案 |
|------|----------|
| 没有测试就重构 | 先写测试 |
| 大爆炸式重构 | 小增量变更 |
| 混合重构和功能 | 分开提交 |
| 过度工程 | YAGNI 原则 |

## 语言特定指南

根据项目语言读取对应参考文件：

| 语言 | 参考文件 |
|------|----------|
| Python | `references/python.md` |
| JavaScript/TypeScript | `references/javascript.md` |
| Java | `references/java.md` |
| C/C++ | `references/cpp.md` |
| Shell/Bash | `references/shell.md` |