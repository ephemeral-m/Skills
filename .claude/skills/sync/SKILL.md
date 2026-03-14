---
name: sync
description: 生成 VS Code SFTP 配置文件，用于同步项目文件到远程 Linux 服务器。当用户需要设置远程文件同步、配置 SFTP、想要将本地文件同步到远程服务器、远程开发调试、部署代码到服务器时使用此 skill。
---

# SFTP 配置生成器

帮助用户生成 VS Code SFTP 扩展的配置文件，使用密码认证实现文件同步。

## 执行步骤

### 1. 检查现有配置

检查 `.vscode/sftp.json` 是否已存在，存在则询问是否覆盖。

### 2. 收集配置信息

| 信息 | 说明 | 默认值 |
|------|------|--------|
| host | 远程服务器地址 | 必填 |
| port | SSH 端口 | 22 |
| username | 用户名 | 必填 |
| password | 密码 | 必填 |
| remotePath | 远程路径 | `/home/{username}/{项目名}` |

### 3. 生成配置文件

创建 `.vscode/sftp.json`：

```json
{
  "name": "{项目名}",
  "host": "{服务器地址}",
  "protocol": "sftp",
  "port": {端口},
  "username": "{用户名}",
  "password": "{密码}",
  "remotePath": "{远程路径}",
  "uploadOnSave": true,
  "useTempFile": false,
  "openSsh": false,
  "ignore": [
    ".git", ".idea", ".claude", ".vscode",
    "node_modules", "__pycache__", "*.pyc"
  ]
}
```

### 4. 执行首次同步

```bash
scp -P {端口} -r . {用户名}@{服务器地址}:{远程路径}
```

或使用 sshpass 自动输入密码：

```bash
sshpass -p '{密码}' scp -P {端口} -r . {用户名}@{服务器地址}:{远程路径}
```

### 5. 告知用户

1. 配置文件位置: `.vscode/sftp.json`
2. 自动同步: `uploadOnSave` 已启用
3. 安全建议: 将 `.vscode/sftp.json` 添加到 `.gitignore`

## VS Code SFTP 扩展使用

### 安装扩展

在 VS Code 中安装：`liximomo.sftp`

### 常用操作

| 操作 | 方式 |
|------|------|
| 上传单个文件 | 右键文件 → SFTP Upload File |
| 下载远程文件 | 右键文件 → SFTP Download File |
| 同步整个项目 | 右键项目根目录 → SFTP Sync Local -> Remote |