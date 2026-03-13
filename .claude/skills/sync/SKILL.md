---
name: sync
description: 生成 VS Code SFTP 配置文件，用于同步项目文件到远程 Linux 服务器。当用户需要设置远程文件同步、配置 SFTP、想要将本地文件同步到远程服务器，或执行 /sync 命令时使用此 skill。
---

# SFTP 配置生成器

帮助用户生成 VS Code SFTP 扩展的配置文件，使用密码认证实现文件同步。

## 执行步骤

### 1. 检查现有配置

首先检查 `.vscode/sftp.json` 是否已存在：

- 如果已存在，询问用户是否需要覆盖现有配置
- 如果用户选择不覆盖，则终止流程

### 2. 收集配置信息

询问用户以下信息（如果用户已提供则跳过）：

| 信息 | 说明 | 默认值 |
|------|------|--------|
| host | 远程服务器地址 | 必填 |
| port | SSH 端口 | 22 |
| username | 用户名 | 必填 |
| password | 密码 | 必填 |
| remotePath | 远程路径 | `/home/{username}/{项目名}` |

### 3. 创建目录

确保 `.vscode` 目录存在：

```bash
mkdir -p .vscode
```

### 4. 生成配置文件

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
    ".git",
    ".idea",
    ".claude",
    ".vscode",
    "node_modules",
    "__pycache__",
    "*.pyc"
  ]
}
```

### 5. 执行首次同步

配置完成后，使用 `scp` 命令执行首次同步：

```bash
scp -P {端口} -r . {用户名}@{服务器地址}:{远程路径}
```

执行时会提示输入密码，输入后即可开始同步。

**使用 sshpass 自动输入密码（可选）**：
```bash
sshpass -p '{密码}' scp -P {端口} -r . {用户名}@{服务器地址}:{远程路径}
```

执行同步命令后，告知用户同步结果。

### 6. 告知用户

配置完成后，告知用户：

1. **配置文件位置**: `.vscode/sftp.json`
2. **认证方式**: 密码认证
3. **自动同步**: `uploadOnSave` 已启用，保存文件时自动同步
4. **首次同步**: 已执行完整同步
5. **安全建议**: 建议将 `.vscode/sftp.json` 添加到 `.gitignore`

## VS Code SFTP 扩展使用说明

### 安装扩展

在 VS Code 中安装扩展：`liximomo.sftp`

### 常用操作

| 操作 | 方式 |
|------|------|
| 上传单个文件 | 右键文件 → SFTP Upload File |
| 下载远程文件 | 右键文件 → SFTP Download File |
| 同步整个项目 | 右键项目根目录 → SFTP Sync Local -> Remote |
| 查看远程文件 | 右键 → SFTP Open Remote File |

## 注意事项

- 密码会明文存储在配置文件中，建议将 `.vscode/sftp.json` 添加到 `.gitignore`
- `uploadOnSave: true` 会在每次保存时自动上传
- 可通过 `ignore` 字段排除不需要同步的文件