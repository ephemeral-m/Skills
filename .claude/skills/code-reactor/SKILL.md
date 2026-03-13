---
name: code-reactor
description: 通过系统性的重构技术（如提取函数、消除重复、简化条件表达式、应用设计模式）改善代码结构、可读性和可维护性，但不改变外部行为。当用户需要减少技术债务、提取函数或类、消除代码重复、简化复杂条件、重命名以提高清晰度、应用设计模式、改善代码组织、降低耦合、提高内聚，或在结构改进过程中保持测试覆盖率时使用此skill。
---

# 代码重构 - 在不改变行为的前提下改善代码结构

## 何时使用此 Skill

- 减少现有代码库的技术债务
- 拆分大文件或大函数
- 消除代码重复（DRY原则）
- 简化复杂的条件逻辑
- 重命名变量、函数以提高清晰度
- 应用设计模式改善结构
- 改善代码组织和文件结构
- 降低模块间耦合
- 提高类/模块内聚
- 重构过程中保持测试覆盖率
- 拆分大文件或大函数
- 逐步现代化遗留代码

---

## 核心原则

1. **行为保持** - 重构绝不改变代码做什么，只改变怎么做
2. **小步前进** - 做微小变更，每步后测试
3. **测试先行** - 重构前确保有全面的测试
4. **一次一事** - 不要混合重构和功能添加
5. **添加功能时重构** - 让代码比你发现时更好

---

## 何时重构

### 触发条件
- **添加功能前** - 为新功能腾出空间
- **代码审查时** - 发现代码异味或令人困惑的部分
- **修复 Bug 时** - 通过更好的结构让 Bug 不可能发生
- **童子军法则** - 永远让代码比你发现时更干净

### 危险信号（代码异味）
```
✗ 函数超过 ~50 行
✗ 条件嵌套过深（>3 层）
✗ 重复代码（复制粘贴编程）
✗ 变量名不清晰（x、temp、data）
✗ 函数参数超过 3 个
✗ 上帝类（类做太多事情）
✗ 参数列表过长
✗ 需要注释解释代码做什么（代码应该自解释）
```

---

## 重构目录

### 1. **提取方法/函数**

**何时使用**: 函数做太多事情或有复杂逻辑

```typescript
// 重构前 - 难以理解
function processOrder(order) {
  // 计算总价
  let total = 0;
  for (const item of order.items) {
    total += item.price * item.quantity;
    if (item.discount) {
      total -= item.price * item.quantity * item.discount;
    }
  }

  // 应用税费
  const tax = total * 0.08;
  total += tax;

  // 检查库存
  for (const item of order.items) {
    const stock = inventory.get(item.id);
    if (stock < item.quantity) {
      throw new Error('库存不足');
    }
  }

  return { total, tax };
}

// 重构后 - 职责清晰
function processOrder(order) {
  validateInventory(order.items);
  const subtotal = calculateSubtotal(order.items);
  const tax = calculateTax(subtotal);
  const total = subtotal + tax;
  return { total, tax };
}

function calculateSubtotal(items) {
  return items.reduce((sum, item) => {
    const itemTotal = item.price * item.quantity;
    const discount = item.discount ? itemTotal * item.discount : 0;
    return sum + itemTotal - discount;
  }, 0);
}

function calculateTax(amount) {
  const TAX_RATE = 0.08;
  return amount * TAX_RATE;
}

function validateInventory(items) {
  for (const item of items) {
    const stock = inventory.get(item.id);
    if (stock < item.quantity) {
      throw new InsufficientStockError(item.id, stock, item.quantity);
    }
  }
}
```

### 2. **用命名常量替换魔法数字**

```typescript
// 重构前 - 这些数字是什么意思？
if (user.age >= 18 && user.age <= 65) {
  premium = basePrice * 1.0;
} else {
  premium = basePrice * 1.5;
}

setTimeout(checkStatus, 60000);

// 重构后 - 自解释
const MIN_STANDARD_AGE = 18;
const MAX_STANDARD_AGE = 65;
const STANDARD_RATE_MULTIPLIER = 1.0;
const HIGH_RISK_RATE_MULTIPLIER = 1.5;
const STATUS_CHECK_INTERVAL_MS = 60 * 1000; // 1 分钟

if (user.age >= MIN_STANDARD_AGE && user.age <= MAX_STANDARD_AGE) {
  premium = basePrice * STANDARD_RATE_MULTIPLIER;
} else {
  premium = basePrice * HIGH_RISK_RATE_MULTIPLIER;
}

setTimeout(checkStatus, STATUS_CHECK_INTERVAL_MS);
```

### 3. **简化条件表达式**

```typescript
// 重构前 - 复杂嵌套条件
function getShippingCost(order) {
  if (order.items.length > 0) {
    if (order.total > 50) {
      if (order.isPremium) {
        return 0;
      } else {
        return 5;
      }
    } else {
      if (order.isPremium) {
        return 5;
      } else {
        return 10;
      }
    }
  } else {
    return 0;
  }
}

// 重构后 - 卫语句和提前返回
function getShippingCost(order) {
  if (order.items.length === 0) return 0;
  if (order.isPremium && order.total > 50) return 0;
  if (order.isPremium) return 5;
  if (order.total > 50) return 5;
  return 10;
}

// 更好的方式 - 策略模式
const SHIPPING_RATES = {
  premiumOverFifty: { cost: 0, applies: (o) => o.isPremium && o.total > 50 },
  premium: { cost: 5, applies: (o) => o.isPremium },
  standardOverFifty: { cost: 5, applies: (o) => o.total > 50 },
  standard: { cost: 10, applies: () => true }
};

function getShippingCost(order) {
  if (order.items.length === 0) return 0;

  for (const rate of Object.values(SHIPPING_RATES)) {
    if (rate.applies(order)) return rate.cost;
  }
}
```

### 4. **提取变量以提高清晰度**

```typescript
// 重构前 - 难以理解
if (
  (platform === 'ios' && version >= 13) ||
  (platform === 'android' && version >= 10) ||
  (platform === 'web' && browserVersion >= 90)
) {
  enableNewUI();
}

// 重构后 - 意图清晰的命名
const isIosSupportedVersion = platform === 'ios' && version >= 13;
const isAndroidSupportedVersion = platform === 'android' && version >= 10;
const isWebSupportedVersion = platform === 'web' && browserVersion >= 90;
const supportsNewUI =
  isIosSupportedVersion ||
  isAndroidSupportedVersion ||
  isWebSupportedVersion;

if (supportsNewUI) {
  enableNewUI();
}
```

### 5. **删除死代码**

```typescript
// 重构前 - 充满未使用的代码
function calculatePrice(item) {
  let price = item.basePrice;

  // 旧折扣系统（已废弃）
  // if (item.category === 'electronics') {
  //   price *= 0.9;
  // }

  // 应用当前折扣
  if (item.discount) {
    price *= (1 - item.discount);
  }

  // 旧税费计算
  // const oldTax = price * 0.05;

  // 新税费计算
  const tax = price * 0.08;

  return price + tax;
}

// 重构后 - 干净且专注
function calculatePrice(item) {
  let price = item.basePrice;

  if (item.discount) {
    price *= (1 - item.discount);
  }

  const TAX_RATE = 0.08;
  const tax = price * TAX_RATE;

  return price + tax;
}
```

### 6. **用卫语句替换嵌套条件**

```typescript
// 重构前 - 深度嵌套
function withdraw(account, amount) {
  if (account.isActive) {
    if (account.balance >= amount) {
      if (amount > 0) {
        if (!account.isFrozen) {
          account.balance -= amount;
          return { success: true, newBalance: account.balance };
        } else {
          return { success: false, error: '账户已冻结' };
        }
      } else {
        return { success: false, error: '金额无效' };
      }
    } else {
      return { success: false, error: '余额不足' };
    }
  } else {
    return { success: false, error: '账户未激活' };
  }
}

// 重构后 - 卫语句
function withdraw(account, amount) {
  if (!account.isActive) {
    return { success: false, error: '账户未激活' };
  }

  if (account.isFrozen) {
    return { success: false, error: '账户已冻结' };
  }

  if (amount <= 0) {
    return { success: false, error: '金额无效' };
  }

  if (account.balance < amount) {
    return { success: false, error: '余额不足' };
  }

  account.balance -= amount;
  return { success: true, newBalance: account.balance };
}
```

### 7. **用多态替换类型码**

```typescript
// 重构前 - 到处检查类型
class Employee {
  constructor(type, salary) {
    this.type = type; // 'engineer', 'manager', 'salesperson'
    this.salary = salary;
  }

  calculateBonus() {
    if (this.type === 'engineer') {
      return this.salary * 0.1;
    } else if (this.type === 'manager') {
      return this.salary * 0.2;
    } else if (this.type === 'salesperson') {
      return this.salary * 0.15;
    }
  }

  getTitle() {
    if (this.type === 'engineer') {
      return '软件工程师';
    } else if (this.type === 'manager') {
      return '工程经理';
    } else if (this.type === 'salesperson') {
      return '销售代表';
    }
  }
}

// 重构后 - 多态
class Employee {
  constructor(salary) {
    this.salary = salary;
  }

  calculateBonus() {
    throw new Error('必须由子类实现');
  }

  getTitle() {
    throw new Error('必须由子类实现');
  }
}

class Engineer extends Employee {
  calculateBonus() {
    return this.salary * 0.1;
  }

  getTitle() {
    return '软件工程师';
  }
}

class Manager extends Employee {
  calculateBonus() {
    return this.salary * 0.2;
  }

  getTitle() {
    return '工程经理';
  }
}

class Salesperson extends Employee {
  calculateBonus() {
    return this.salary * 0.15;
  }

  getTitle() {
    return '销售代表';
  }
}
```

### 8. **合并重复代码**

```typescript
// 重构前 - 重复逻辑
function calculateEmployeeBonus(employee) {
  let bonus = employee.salary * 0.1;
  if (employee.yearsOfService > 5) {
    bonus += 1000;
  }
  if (employee.hasTopPerformance) {
    bonus *= 1.5;
  }
  return bonus;
}

function calculateContractorBonus(contractor) {
  let bonus = contractor.salary * 0.1;
  if (contractor.yearsOfService > 5) {
    bonus += 1000;
  }
  if (contractor.hasTopPerformance) {
    bonus *= 1.5;
  }
  return bonus;
}

// 重构后 - 共享逻辑
function calculateBonus(person) {
  let bonus = person.salary * 0.1;

  if (person.yearsOfService > 5) {
    bonus += 1000;
  }

  if (person.hasTopPerformance) {
    bonus *= 1.5;
  }

  return bonus;
}

// 两者都可以使用
const employeeBonus = calculateBonus(employee);
const contractorBonus = calculateBonus(contractor);
```

---

## 重构流程

### 逐步方法

```
1. 识别异味或改进机会
2. 确保测试存在且通过
3. 做一个小重构变更
4. 运行测试 - 必须仍然通过
5. 提交（可选但推荐）
6. 重复步骤 3-5 直到满意
7. 最终测试运行
8. 代码审查
```

### 流程示例

```typescript
// 原始代码
function process(data) {
  let result = [];
  for (let i = 0; i < data.length; i++) {
    if (data[i].status === 'active' && data[i].age >= 18) {
      result.push({
        id: data[i].id,
        name: data[i].name,
        email: data[i].email
      });
    }
  }
  return result;
}

// 步骤 1: 提取条件
function isEligible(item) {
  return item.status === 'active' && item.age >= 18;
}

function process(data) {
  let result = [];
  for (let i = 0; i < data.length; i++) {
    if (isEligible(data[i])) {
      result.push({
        id: data[i].id,
        name: data[i].name,
        email: data[i].email
      });
    }
  }
  return result;
}
// 测试 ✓

// 步骤 2: 用数组方法替换循环
function process(data) {
  let result = [];
  data.forEach(item => {
    if (isEligible(item)) {
      result.push({
        id: item.id,
        name: item.name,
        email: item.email
      });
    }
  });
  return result;
}
// 测试 ✓

// 步骤 3: 提取转换
function transformToUser(item) {
  return {
    id: item.id,
    name: item.name,
    email: item.email
  };
}

function process(data) {
  let result = [];
  data.forEach(item => {
    if (isEligible(item)) {
      result.push(transformToUser(item));
    }
  });
  return result;
}
// 测试 ✓

// 步骤 4: 使用 filter 和 map
function process(data) {
  return data
    .filter(isEligible)
    .map(transformToUser);
}
// 测试 ✓

// 最终结果 - 清晰、函数式、可测试
```

---

## 常见陷阱

### ❌ 没有测试就重构
```
如果测试不存在，先写测试！
否则，你无法验证行为是否保持不变。
```

### ❌ 大爆炸式重构
```
不要一次性重写所有内容。
小的、增量的变更更安全，也更容易审查。
```

### ❌ 混合重构和功能
```
分开提交:
- 提交 1: 重构（无行为变更）
- 提交 2: 添加功能（使用重构后的代码）
```

### ❌ 过度工程
```
不要"为未来需求"添加复杂性
按需重构，而非投机性重构。
YAGNI: 你不会需要它
```

---

## 工具

### IDE 重构工具
```
✓ 重命名（安全重命名所有文件）
✓ 提取方法/函数
✓ 提取变量
✓ 内联变量/函数
✓ 修改签名
✓ 移动到文件/模块
```

### 静态分析
```bash
# JavaScript/TypeScript
eslint --fix
prettier --write

# Python
pylint
black

# 发现代码异味
# PMD, SonarQube, CodeClimate
```

---

## 参考资源

- [Martin Fowler 的重构](https://refactoring.com/)
- [重构目录](https://refactoring.guru/refactoring/catalog)
- [Robert Martin 的代码整洁之道](https://www.amazon.com/Clean-Code-Handbook-Software-Craftsmanship/dp/0132350882)
- [Michael Feathers 的修改代码的艺术](https://www.amazon.com/Working-Effectively-Legacy-Michael-Feathers/dp/0131177052)

---

**记住**: 重构是持续改进。每次接触代码时，让它变得更好一点。小的、频繁的重构优于罕见的大规模重写。