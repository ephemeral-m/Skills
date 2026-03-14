---
name: fix-loop
description: 自动修复循环 Skill，基于执行结果的自动修复循环。当需要自动迭代修复构建/测试错误、持续尝试直到成功或达到上限时使用此 skill。
---

# fix-loop Skill

基于执行结果的自动修复循环，支持多语言、多模块的渐进式错误修复。

## 触发方式

- 手动调用: `/fix-loop [command]`
- 自动触发: 通过 PostToolUse Hook 在命令失败时触发

## 执行流程

```
执行命令 → 分析结果 → AI修复 → 重新执行 → 循环直到成功或达到上限
```

## 参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| command | 要执行的命令 (build/test/verify) | 必填 |
| --max-iterations | 最大循环次数 | 5 |
| --module | 指定模块 | 可选 |

## 使用示例

```bash
/fix-loop build                    # 自动修复构建错误
/fix-loop test --max-iterations 3  # 最多尝试3次
/fix-loop verify --module core     # 验证指定模块
```

## 终止条件

- 执行成功
- 达到最大循环次数
- 无法识别的错误类型