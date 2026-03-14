---
name: fix-compile
description: 编译错误修复 Skill，支持 C 和 Lua（OpenResty）。当构建失败、出现编译错误、链接错误、头文件缺失、未声明变量/函数等错误时使用此 skill。
---

# fix-compile Skill

编译错误修复 Skill，支持 C 和 Lua（OpenResty）。

## 触发条件

- 用户调用 `/fix-compile [module]`
- 构建失败且错误类型为 compile

## 渐进式修复流程

```
Phase 0: 规则匹配（零 Token）
    │ 读取 tools/fixers/compile/{c,lua}.yaml
    │ 匹配预定义错误模式
    ▼
Phase 1: 轻量分析
    │ 只加载错误上下文
    ▼
Phase 2: 完整分析
    │ 加载完整项目上下文
```

## 支持的语言

| 语言 | 说明 | 规则文件 |
|------|------|----------|
| C | OpenResty 核心 | `tools/fixers/compile/c.yaml` |
| Lua | OpenResty 插件 | `tools/fixers/compile/lua.yaml` |

## 用法

```bash
/fix-compile           # 修复最近的构建错误
/fix-compile openresty # 修复指定模块
```

## 相关文件

- 结果: `tools/results/build-*.json`
- C 规则: `tools/fixers/compile/c.yaml`
- Lua 规则: `tools/fixers/compile/lua.yaml`