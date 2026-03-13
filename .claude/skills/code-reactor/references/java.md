# Java 重构指南

## 目录
- [特定重构技术](#特定重构技术)
- [代码示例](#代码示例)
- [工具推荐](#工具推荐)
- [常见陷阱](#常见陷阱)

---

## 特定重构技术

### 1. 用枚举替换常量

```java
// 重构前
public class Constants {
    public static final int STATUS_PENDING = 0;
    public static final int STATUS_APPROVED = 1;
    public static final int STATUS_REJECTED = 2;
}

// 重构后
public enum Status {
    PENDING(0, "待审批"),
    APPROVED(1, "已批准"),
    REJECTED(2, "已拒绝");

    private final int code;
    private final String description;

    Status(int code, String description) {
        this.code = code;
        this.description = description;
    }

    public int getCode() { return code; }
    public String getDescription() { return description; }
}
```

### 2. 用 Stream API 替换循环

```java
// 重构前
List<String> activeEmails = new ArrayList<>();
for (User user : users) {
    if (user.isActive()) {
        activeEmails.add(user.getEmail());
    }
}

// 重构后
List<String> activeEmails = users.stream()
    .filter(User::isActive)
    .map(User::getEmail)
    .collect(Collectors.toList());
```

### 3. 用 Optional 避免 NullPointerException

```java
// 重构前
public String getCity(User user) {
    if (user != null && user.getAddress() != null) {
        return user.getAddress().getCity();
    }
    return "Unknown";
}

// 重构后
public String getCity(User user) {
    return Optional.ofNullable(user)
        .map(User::getAddress)
        .map(Address::getCity)
        .orElse("Unknown");
}
```

### 4. 用记录类简化数据类 (Java 17+)

```java
// 重构前
public final class User {
    private final String name;
    private final int age;

    public User(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public String getName() { return name; }
    public int getAge() { return age; }

    @Override
    public boolean equals(Object o) { /* ... */ }
    @Override
    public int hashCode() { /* ... */ }
    @Override
    public String toString() { /* ... */ }
}

// 重构后 (Java 17+)
public record User(String name, int age) {}
```

### 5. 用多态替换条件

```java
// 重构前
public double calculateDiscount(Customer customer) {
    switch (customer.getType()) {
        case "regular": return 0.05;
        case "silver": return 0.10;
        case "gold": return 0.15;
        default: return 0;
    }
}

// 重构后
public interface Customer {
    double getDiscountRate();
}

public class RegularCustomer implements Customer {
    public double getDiscountRate() { return 0.05; }
}

public class GoldCustomer implements Customer {
    public double getDiscountRate() { return 0.15; }
}

// 使用
double discount = customer.getDiscountRate();
```

### 6. 用 Builder 模式处理多参数

```java
// 重构前
User user = new User("张三", 25, "zhang@example.com", "北京市", "工程师", 5000);

// 重构后
User user = User.builder()
    .name("张三")
    .age(25)
    .email("zhang@example.com")
    .city("北京市")
    .position("工程师")
    .salary(5000)
    .build();
```

### 7. 用 try-with-resources 管理资源

```java
// 重构前
BufferedReader reader = null;
try {
    reader = new BufferedReader(new FileReader("file.txt"));
    String line = reader.readLine();
} catch (IOException e) {
    e.printStackTrace();
} finally {
    if (reader != null) {
        try {
            reader.close();
        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}

// 重构后
try (BufferedReader reader = new BufferedReader(new FileReader("file.txt"))) {
    String line = reader.readLine();
} catch (IOException e) {
    e.printStackTrace();
}
```

---

## 工具推荐

```bash
# IDE 重构工具 (推荐)
# - IntelliJ IDEA
# - Eclipse

# 静态分析
# - SonarQube
# - SpotBugs
# - PMD

# 代码格式化
# - google-java-format
# - Spotless

# 依赖管理
# - Maven
# - Gradle
```

---

## 常见陷阱

### 字符串比较
```java
// 错误
if (str == "hello") { ... }

// 正确
if ("hello".equals(str)) { ... }
if (Objects.equals(str, "hello")) { ... }
```

### 可变对象暴露
```java
// 错误
public List<String> getItems() {
    return items; // 暴露内部状态
}

// 正确
public List<String> getItems() {
    return Collections.unmodifiableList(items);
    // 或
    return new ArrayList<>(items);
}
```

### 忽略异常
```java
// 错误
try {
    doSomething();
} catch (Exception e) {
    // 吞掉异常
}

// 正确
try {
    doSomething();
} catch (Exception e) {
    logger.error("操作失败", e);
    throw new BusinessException("操作失败", e);
}
```