# 工业级 AI 开发框架

基于 Claude Code 构建的 OpenResty 工程开发框架。

## 目录结构

```
tools/
├── bin/
│   └── dev              # 主 CLI（Python，零 Token）
├── config/
│   └── dev.yaml         # 项目配置
├── scripts/
│   ├── common.sh        # 公共函数
│   ├── build.sh         # 构建脚本
│   ├── test.sh          # 测试脚本
├── fixers/
│   └── compile/
│       ├── c.yaml       # C/Nginx 错误规则
│       └── lua.yaml     # Lua 错误规则
├── results/             # 结构化结果
└── state/               # 运行状态
```

## 用法

```bash
/dev build           # 构建
/dev build openresty # 构建指定模块
/dev test            # 测试
/dev verify          # 完整验证
/dev status          # 查看状态
/dev clean           # 清理
```

## 渐进式修复

| Phase | Token 消耗 | 说明 |
|-------|-----------|------|
| Phase 0 | **零** | 匹配预定义规则 |
| Phase 1 | **轻量** | 只加载错误上下文 |
| Phase 2 | **完整** | 加载完整项目上下文 |

## Skills

| Skill | 用途 |
|-------|------|
| `/dev` | 统一开发命令入口 |
| `/fix-compile` | 编译错误修复 |
| `/fix-test` | 测试失败修复 |
| `/fix-runtime` | 运行时错误修复 |