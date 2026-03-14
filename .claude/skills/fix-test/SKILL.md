---
name: fix-test
description: 测试失败修复 Skill。当单元测试失败、集成测试失败、断言错误、测试超时时使用此 skill。
---

# fix-test Skill

测试失败修复 Skill，分析并修复测试失败问题。

## 触发条件

- 用户调用 `/fix-test [module]`
- 测试执行失败

## 流程

1. 读取 `tools/results/test-{module}.json`
2. 分析失败测试和错误信息
3. 定位问题代码
4. 生成修复方案

## 用法

```bash
/fix-test           # 修复最近的测试失败
/fix-test openresty # 修复指定模块
```

## 常见测试问题

| 问题类型 | 说明 |
|----------|------|
| 断言失败 | 预期值与实际值不符 |
| 超时 | 测试执行超时 |
| 环境问题 | 测试环境配置错误 |
| 依赖问题 | 测试依赖缺失或版本不匹配 |