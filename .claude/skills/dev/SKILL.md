---
name: dev
description: 统一开发命令入口，零 Token 消耗执行 build/test/verify/clean 等工程任务。当用户需要构建项目、运行测试、验证代码、清理构建产物、查看项目状态、同步代码到远程服务器时使用此 skill。
---

# dev Slash Command

统一开发命令入口，零 Token 消耗执行 build/test/verify/clean 等工程任务。

## 用法

```
/dev build [module]     # 编译指定模块或全部
/dev test [module]      # 测试指定模块或全部
/dev clean              # 清理构建产物
/dev verify             # 完整验证流程（build + test）
/dev status             # 查看项目状态
/dev sync [remote]      # 同步代码到远程服务器
```

## 流程

1. 解析用户命令和参数
2. 执行 `tools/bin/dev` 脚本
3. 如果失败，输出结构化错误并建议修复 Skill

## 错误处理

命令失败时，脚本自动检测错误类型并建议对应的 `/fix-*` Skill。

## 相关文件

| 文件 | 说明 |
|------|------|
| `tools/bin/dev` | Python CLI 主程序 |
| `tools/scripts/*.sh` | Shell 脚本 |
| `tools/config/dev.yaml` | 项目配置 |
| `tools/results/*.json` | 构建结果 |