# Feedback Skill

自动优化反馈机制，在开发过程中学习并更新项目知识库。

## 触发条件

- 用户说 "记住这个"、"更新文档"、"反馈到 skill"
- 会话中修复了重复出现的错误
- 发现新的最佳实践模式
- 发现新的架构设计模式
- 用户调用 `/feedback` 命令

## 反馈目标

| 目标 | 内容 | 更新频率 |
|------|------|----------|
| MEMORY.md | 会话记忆、临时发现 | 每次会话 |
| SKILL 文件 | 技能知识、修复规则 | 发现新模式时 |
| CLAUDE.md | 项目规范、工作流程 | 重大变更时 |
| patterns.yaml | 可复用模式库 | 验证有效后 |

## 工作流程

1. **收集**: 分析会话中的问题和解决方案
2. **识别**: 匹配已有模式或发现新模式
3. **验证**: 确保信息准确有效
4. **更新**: 写入对应的知识库文件

## 架构设计理念自动抽象

当在开发过程中发现以下情况时，自动提示更新到相关 SKILL：

### 触发条件

1. **新增模块或目录结构**
   - 检测到新的目录层级
   - 发现新的文件组织模式
   - 提示：是否更新 SKILL 的目录结构定义

2. **新增数据流模式**
   - 发现新的 API 调用链路
   - 发现新的数据转换流程
   - 提示：是否更新 SKILL 的数据流设计

3. **新增组件设计模式**
   - 发现新的表单/表格组件结构
   - 发现新的状态管理方式
   - 提示：是否更新 SKILL 的组件设计模式

4. **新增配置模型**
   - 发现新的 JSON 配置格式
   - 发现新的 nginx 配置生成规则
   - 提示：是否更新 SKILL 的配置数据模型

### 抽象规则

```yaml
# 架构抽象检测规则
architecture_abstraction:
  directory_pattern:
    trigger: "新增目录深度 >= 3 或 新增文件类型"
    action: "提示更新目录结构到 SKILL"

  data_flow_pattern:
    trigger: "新增 API 端点 或 新增数据转换步骤"
    action: "提示更新数据流设计到 SKILL"

  component_pattern:
    trigger: "新增 Vue 组件 或 新增 Lua 模块"
    action: "提示更新组件设计模式到 SKILL"

  config_pattern:
    trigger: "新增 JSON 字段 或 新增 nginx 指令生成"
    action: "提示更新配置数据模型到 SKILL"
```

### 反馈提示格式

```
[feedback] 检测到架构设计变更：

新增内容:
  - 目录: src/loadbalance/
  - 数据流: JSON → generator.lua → nginx.conf
  - API: POST /api/deploy/apply

建议更新:
  1. MEMORY.md - 记录新目录路径
  2. web-admin-frontend SKILL - 更新数据流设计
  3. patterns.yaml - 添加部署流程模式

是否执行更新? [Y/n/a(全部)]
```

## 使用方式

```bash
/feedback              # 查看当前会话的可优化建议
/feedback apply        # 应用所有建议的更新
/feedback status       # 查看反馈系统状态
/feedback clean        # 清理过时的记忆
/feedback architecture # 查看架构变更摘要
```

## 更新规则

### 路径配置
当发现路径变化时更新：
- `tools/scripts/common.sh` 中的路径定义
- `tools/bin/dev` 中的默认路径
- MEMORY.md 中的项目路径记录

### 错误修复规则
当同一错误修复 2 次以上时：
- 在 `tools/fixers/` 下创建或更新规则文件
- 更新 SKILL 中的错误处理逻辑

### 最佳实践
当验证有效的解决方案时：
- 记录到 MEMORY.md
- 如适用范围广，更新对应 SKILL

### 架构设计理念
当发现新的架构模式时：
- 抽象为可复用的设计模式
- 更新到对应的 SKILL 参考文档
- 更新 patterns.yaml 中的架构模式

## 输出格式

更新时使用统一的提交格式：
```
[feedback] 更新 <target>: <description>

变更内容:
- 添加/修改: <具体内容>
- 原因: <为什么需要这个变更>
- 影响: <影响范围>
```

## 架构模式记录模板

当发现新架构模式时，按以下格式记录：

```yaml
# 在 patterns.yaml 中添加
architecture_patterns:
  - name: "配置驱动架构"
    description: "JSON 配置 → 配置生成器 → nginx.conf"
    components:
      - "JSON 配置存储"
      - "配置生成器 (generator.lua)"
      - "部署控制器 (deploy.lua)"
    data_flow:
      - "用户修改 JSON"
      - "API 保存配置"
      - "生成器转换格式"
      - "控制器验证并重载"
    applicable_to:
      - "需要动态配置的场景"
      - "配置需要版本管理的场景"
    benefits:
      - "配置与代码分离"
      - "支持回滚"
      - "可视化配置"
```