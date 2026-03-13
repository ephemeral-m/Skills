# JavaScript/TypeScript 重构指南

## 目录
- [特定重构技术](#特定重构技术)
- [代码示例](#代码示例)
- [工具推荐](#工具推荐)
- [常见陷阱](#常见陷阱)

---

## 特定重构技术

### 1. 用对象替换 switch

```typescript
// 重构前
function getDiscount(type: string): number {
  switch (type) {
    case 'regular': return 0.05;
    case 'silver': return 0.10;
    case 'gold': return 0.15;
    default: return 0;
  }
}

// 重构后
const DISCOUNTS: Record<string, number> = {
  regular: 0.05,
  silver: 0.10,
  gold: 0.15,
};

const getDiscount = (type: string): number => DISCOUNTS[type] ?? 0;
```

### 2. 用解构简化代码

```typescript
// 重构前
function processUser(user: User) {
  const name = user.name;
  const email = user.email;
  const age = user.age;
  console.log(name, email, age);
}

// 重构后
function processUser({ name, email, age }: User) {
  console.log(name, email, age);
}
```

### 3. 用可选链和空值合并

```typescript
// 重构前
const street = user && user.address && user.address.street
  ? user.address.street
  : 'Unknown';

// 重构后
const street = user?.address?.street ?? 'Unknown';
```

### 4. 用数组方法替换循环

```typescript
// 重构前
const activeEmails: string[] = [];
for (const user of users) {
  if (user.isActive) {
    activeEmails.push(user.email);
  }
}

// 重构后
const activeEmails = users
  .filter(user => user.isActive)
  .map(user => user.email);
```

### 5. 用 async/await 替换回调地狱

```typescript
// 重构前
function fetchUserData(userId: string, callback: (data: User) => void) {
  fetchUser(userId, (user) => {
    fetchProfile(user.profileId, (profile) => {
      fetchSettings(profile.settingsId, (settings) => {
        callback({ ...user, profile, settings });
      });
    });
  });
}

// 重构后
async function fetchUserData(userId: string): Promise<User> {
  const user = await fetchUser(userId);
  const profile = await fetchProfile(user.profileId);
  const settings = await fetchSettings(profile.settingsId);
  return { ...user, profile, settings };
}
```

### 6. 用接口/类型定义结构

```typescript
// 重构前
function processOrder(order: any) {
  return order.items.reduce((sum: number, item: any) => {
    return sum + item.price * item.quantity;
  }, 0);
}

// 重构后
interface OrderItem {
  price: number;
  quantity: number;
}

interface Order {
  items: OrderItem[];
}

function processOrder(order: Order): number {
  return order.items.reduce((sum, item) => {
    return sum + item.price * item.quantity;
  }, 0);
}
```

### 7. 用策略模式替换复杂条件

```typescript
// 重构前
function calculateShipping(order: Order): number {
  if (order.type === 'express') {
    return order.weight * 2 + 10;
  } else if (order.type === 'standard') {
    return order.weight * 1 + 5;
  } else if (order.type === 'economy') {
    return order.weight * 0.5 + 2;
  }
  return 0;
}

// 重构后
const shippingStrategies = {
  express: (weight: number) => weight * 2 + 10,
  standard: (weight: number) => weight * 1 + 5,
  economy: (weight: number) => weight * 0.5 + 2,
};

function calculateShipping(order: Order): number {
  const strategy = shippingStrategies[order.type];
  return strategy ? strategy(order.weight) : 0;
}
```

---

## 工具推荐

```bash
# 代码格式化
npm install -g prettier
prettier --write .

# Lint 检查
npm install -g eslint
eslint --fix .

# 自动导入排序
npm install -g eslint-plugin-import

# TypeScript 重构
# IDE 内置: VS Code, WebStorm

# 代码迁移工具
npm install -g ts-morph
```

---

## 常见陷阱

### var 变量提升
```typescript
// 错误
for (var i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 100);
} // 输出: 3, 3, 3

// 正确
for (let i = 0; i < 3; i++) {
  setTimeout(() => console.log(i), 100);
} // 输出: 0, 1, 2
```

### this 绑定问题
```typescript
// 错误
class Counter {
  count = 0;
  increment() {
    this.count++;
  }
}
const c = new Counter();
const fn = c.increment;
fn(); // TypeError: this is undefined

// 正确
class Counter {
  count = 0;
  increment = () => {
    this.count++;
  };
}
```

### 过度使用 any
```typescript
// 错误
function process(data: any) {
  return data.value; // 无类型检查
}

// 正确
interface Data {
  value: string;
}
function process(data: Data) {
  return data.value; // 有类型检查
}
```