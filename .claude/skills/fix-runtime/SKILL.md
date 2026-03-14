---
name: fix-runtime
description: 运行时错误修复 Skill，支持 OpenResty/Nginx 运行时问题。当出现 Segmentation Fault、Nginx 错误、Lua 运行时错误、空指针访问、内存越界时使用此 skill。
---

# fix-runtime Skill

运行时错误修复 Skill，支持 OpenResty/Nginx 运行时问题。

## 触发条件

- Segmentation Fault
- Nginx 错误日志 (emerg/alert/crit)
- Lua 运行时错误

## 支持的错误类型

| 类型 | 说明 | 常见原因 |
|------|------|----------|
| Segmentation Fault | 段错误 | 空指针、数组越界 |
| Nginx Error | 配置/模块错误 | 配置语法、模块加载失败 |
| Lua Error | Lua 运行时错误 | nil 索引、类型错误 |

## 用法

```bash
/fix-runtime         # 修复运行时错误
/fix-runtime core    # 修复核心模块
```

## 调试步骤

1. 检查错误日志（`logs/error.log`）
2. 分析核心转储（core dump）
3. 定位错误代码位置
4. 分析调用栈