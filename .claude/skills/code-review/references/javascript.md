# JavaScript/TypeScript 代码审查指南

## 常见问题检查

### 安全问题

```typescript
// ❌ XSS 漏洞
element.innerHTML = userInput;

// ✅ 安全替代
element.textContent = userInput;
// 或使用 DOMPurify
element.innerHTML = DOMPurify.sanitize(userInput);

// ❌ eval 注入
eval(userInput);

// ✅ 安全替代
JSON.parse(userInput);

// ❌ 原型污染
Object.assign(target, userObject);

// ✅ 安全替代
{ ...target, ...userObject }  // 仅 own properties
```

### 异步问题

```typescript
// ❌ 未处理的 Promise
fetch(url).then(res => res.json());

// ✅ 处理错误
try {
  const res = await fetch(url);
  return res.json();
} catch (e) {
  logger.error(e);
  throw e;
}

// ❌ Promise 构造函数反模式
new Promise((resolve, reject) => {
  fs.readFile(path, (err, data) => {
    if (err) reject(err);
    else resolve(data);
  });
});

// ✅ 使用 promisify 或 fs.promises
import { promises as fs } from 'fs';
const data = await fs.readFile(path);
```

### 性能问题

```typescript
// ❌ 循环中的 await
for (const url of urls) {
  await fetch(url);
}

// ✅ 并行执行
await Promise.all(urls.map(url => fetch(url)));

// ❌ 在渲染循环中创建函数
function List({ items }) {
  return items.map(item =>
    <Item onClick={() => handleClick(item.id)} />  // 每次渲染新函数
  );
}

// ✅ 使用 useCallback
const handleClick = useCallback((id) => {
  // ...
}, []);
```

### 类型安全

```typescript
// ❌ 使用 any
function process(data: any) {
  return data.value;
}

// ✅ 定义具体类型
interface Data {
  value: string;
}
function process(data: Data) {
  return data.value;
}

// ❌ 类型断言过度使用
const value = data as string;

// ✅ 类型守卫
if (typeof data === 'string') {
  const value = data;
}
```

---

## TypeScript 特有检查点

### 严格模式

```typescript
// ❌ 隐式 any
function fn(param) {  // 参数隐式 any
  return param;
}

// ✅ 显式类型
function fn(param: unknown) {
  if (typeof param === 'string') {
    return param;
  }
}
```

### 空值处理

```typescript
// ❌ 可能的 null/undefined
const name = user.profile.name;  // profile 可能为 null

// ✅ 可选链
const name = user.profile?.name;

// ✅ 空值合并
const name = user.profile?.name ?? 'Unknown';
```

---

## 检查清单

```
□ innerHTML 改用 textContent 或 DOMPurify
□ 禁止使用 eval
□ 所有 Promise 都有错误处理
□ 避免原型污染
□ 类型注解完整，避免 any
□ 使用可选链处理可能为 null 的属性
□ 避免在循环中使用 await
□ React 组件使用 useCallback/useMemo 优化
□ 使用 const/let 替代 var
□ 异步函数正确使用 async/await
```

---

## 工具推荐

```bash
# Lint
eslint src/ --ext .ts,.tsx
eslint-plugin-security

# 类型检查
tsc --noEmit

# 安全检查
npm audit
snyk test

# 格式化
prettier --write .
```