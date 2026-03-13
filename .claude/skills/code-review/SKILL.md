---
name: code-review
description: 系统性地审查Pull Request、功能实现和代码变更，确保质量、可维护性、安全性和最佳实践。当用户需要合并前代码审查、同行评审、自我审查、代码质量审计、安全漏洞检查、编码标准一致性验证、测试覆盖率验证、性能影响评估、架构决策评估，或提供建设性反馈以提升团队代码质量时使用此 skill。
---

# 代码审查 - 系统性代码质量分析

## 何时使用此 Skill

- 合并到主分支前审查Pull Request、功能实现和代码变更
- 自我审查或为团队成员进行代码审查
- 审计代码质量和标准合规性
- 检查安全漏洞和不良实践
- 验证测试覆盖率是否充分
- 评估变更的性能影响
- 评估架构和设计决策
- 确保与项目编码标准一致
- 提供建设性反馈以提升代码质量
- 审查关键业务逻辑或敏感操作
- 检查常见反模式和代码异味

---

## 核心原则

1. **先理解再审查** - 确保理解意图和上下文后再提出修改建议
2. **具体且可操作** - 指出具体行号并提供明确建议
3. **平衡优点和改进** - 在建议改进的同时认可良好的模式
4. **关注影响** - 从功能、可靠性、性能、可服务性、可演进性多方面的影响进行分析评估
5. **教育而非仅仅纠正** - 解释*为什么*很重要

---

## 审查检查清单

### 1. **正确性与逻辑**
```
✓ 代码是否实现了声称的功能？
✓ 边界情况是否处理（null、空值、边界值）？
✓ 是否存在潜在的竞态条件或时序问题？
✓ 错误处理是否恰当且完整？
✓ 假设是否经过验证？
```

### 2. **安全性**
```
✓ 所有用户输入是否经过验证？
✓ SQL 注入、XSS、CSRF 防护？
✓ 密钥/凭证是否安全存储（环境变量，非硬编码）？
✓ 认证和授权检查？
✓ 公共端点是否有限流？
```

### 3. **性能**
```
✓ 是否存在 N+1 查询问题？
✓ 是否有不必要的数据库调用或 API 请求？
✓ 内存泄漏（事件监听器、订阅）？
✓ 算法效率（避免 O(n²) 当 O(n log n) 可行时）？
```

### 4. **可维护性**
```
✓ 变量/函数名称清晰且具有描述性？
✓ 函数职责单一（单一职责原则）？
✓ DRY - 无复制粘贴重复？
✓ 魔法数字是否替换为命名常量？
✓ 复杂逻辑是否有注释说明？
```

### 5. **测试**
```
✓ 测试覆盖正常路径和错误情况？
✓ 测试是否确定性（无不稳定测试）？
✓ 边界情况是否测试？
✓ 集成点是否正确模拟/存根？
✓ 测试名称是否描述验证内容？
```

### 6. **代码风格与标准**
```
✓ 与项目约定一致？
✓ 遵循语言习惯？
✓ 无未使用的导入或死代码？
✓ 抛出/返回正确的错误类型？
✓ TypeScript 类型具体（非 'any'）？
```

---

## 审查流程

### 步骤 1：高层审查
```
1. 阅读 PR 描述和关联的 issue
2. 理解变更背后的"原因"
3. 扫描文件列表 - 范围是否与描述匹配？
4. 检查缺失文件（测试、迁移、文档）
```

### 步骤 2：深度代码审查
```
1. 首先审查关键路径（安全、数据完整性）
2. 检查测试覆盖率和质量
3. 寻找架构问题
4. 审查错误处理
5. 检查性能问题
```

### 步骤 3：提供反馈
```
格式: [严重程度] 问题 - 具体建议

示例:
[严重] 第 45 行存在 SQL 注入漏洞
- 使用参数化查询而非字符串拼接
- 修改: `query = f"SELECT * FROM users WHERE id = {user_id}"`
- 改为: `query = "SELECT * FROM users WHERE id = ?"` 并使用参数

[建议] 考虑将这个 50 行函数拆分成更小的部分
- 第 100-150 行可以拆分为:
  - `validateInput()` (第 100-120 行)
  - `processData()` (第 121-140 行)
  - `formatOutput()` (第 141-150 行)
```

---

## 反馈严重程度

- **[严重]** - 安全问题、数据丢失风险、功能损坏
- **[重要]** - 性能问题、错误处理不当、逻辑错误
- [次要] - 代码异味、可维护性问题、风格不一致
- [建议] - 锦上添花的改进、替代方案
- [表扬] - 值得强调的优秀模式

---

## 代码审查示例

**Pull Request**: 添加用户认证端点

### 审查意见:

**[严重] 密码修改端点缺少认证（第 67 行）**
```typescript
// 当前 - 无认证检查
app.post('/change-password', (req, res) => {
  const { userId, newPassword } = req.body;
  updatePassword(userId, newPassword);
});

// 应该改为:
app.post('/change-password', requireAuth, (req, res) => {
  // 只允许用户修改自己的密码
  if (req.user.id !== req.body.userId) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  const { newPassword } = req.body;
  updatePassword(req.user.id, newPassword);
});
```

**[重要] 密码存储前未哈希（第 23 行）**
```typescript
// 永远不要存储明文密码
await db.users.update({ password: req.body.password }); // ❌

// 使用 bcrypt 或 argon2
const hashedPassword = await bcrypt.hash(req.body.password, 10);
await db.users.update({ passwordHash: hashedPassword }); // ✅
```

**[次要] Token 过期时间使用魔法数字（第 45 行）**
```typescript
const token = jwt.sign(payload, secret, { expiresIn: 3600 }); // ❌

// 使用命名常量
const TOKEN_EXPIRY_SECONDS = 60 * 60; // 1 小时
const token = jwt.sign(payload, secret, { expiresIn: TOKEN_EXPIRY_SECONDS }); // ✅
```

**[表扬] 出色的输入验证（第 12-20 行）**
这里的 zod schema 非常全面，包含所有必要的检查。这防止了格式错误的数据进入数据库。

---

## 需要标记的常见反模式

### 1. **静默失败**
```typescript
// 错误 - 错误被忽略
try {
  await criticalOperation();
} catch (e) {
  console.log('oops'); // ❌
}

// 正确 - 正确的错误处理
try {
  await criticalOperation();
} catch (e) {
  logger.error('关键操作失败', { error: e, context: {...} });
  throw new CriticalOperationError('处理失败', { cause: e });
}
```

### 2. **回调地狱**
```typescript
// 错误
getData((data) => {
  processData(data, (result) => {
    saveResult(result, (saved) => {
      // 嵌套 3+ 层 ❌
    });
  });
});

// 正确 - 使用 async/await
const data = await getData();
const result = await processData(data);
const saved = await saveResult(result);
```

### 3. **上帝函数**
```typescript
// 错误 - 函数做太多事情
function handleUserRequest(req) {
  // 200 行验证、处理、格式化、保存 ❌
}

// 正确 - 拆分职责
function handleUserRequest(req) {
  const validated = validateRequest(req);
  const processed = processUserData(validated);
  const formatted = formatResponse(processed);
  return saveAndRespond(formatted);
}
```

---

## 何时阻止 vs 批准并评论

**阻止合并（要求修改）：**
- 安全漏洞
- 数据丢失风险
- 功能损坏
- 缺少关键测试
- 重大性能问题

**批准并评论：**
- 风格改进
- 重构建议
- 小的性能优化
- 文档增强
- 可选的测试

---

## 自动化检查

手动审查前，确保自动化检查通过：
```bash
✓ Lint 检查（ESLint、Pylint 等）
✓ 类型检查（TypeScript、mypy）
✓ 单元测试通过
✓ 集成测试通过
✓ 代码覆盖率达标
✓ 安全扫描（SAST）
✓ 依赖漏洞扫描
```

---

## 审查响应模板

```markdown
## 概要
[PR 的高层评估]

## 严重问题
- [列出阻塞性问题]

## 重要问题
- [列出重要但非阻塞的问题]

## 建议
- [列出可选的改进]

## 亮点
- [指出做得好的模式]

## 问题
- [关于意图或方法的澄清问题]

## 审批状态
- [ ] 批准 - 可以合并
- [ ] 批准但有次要评论
- [ ] 要求修改 - 需要解决阻塞性问题
```

---

## 参考资源

- [Google 代码审查指南](https://google.github.io/eng-practices/review/)
- [规范化评论](https://conventionalcomments.org/)
- [代码审查最佳实践](https://docs.gitlab.com/ee/development/code_review.html)

---

**记住**: 目标是提升代码质量同时保持团队士气。要彻底但尊重，具体但不过于苛求，始终解释建议背后的"原因"。