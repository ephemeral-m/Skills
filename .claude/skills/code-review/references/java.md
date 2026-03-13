# Java 代码审查指南

## 常见问题检查

### 安全问题

```java
// ❌ SQL 注入
String query = "SELECT * FROM users WHERE id = " + userId;

// ✅ 使用 PreparedStatement
String query = "SELECT * FROM users WHERE id = ?";
PreparedStatement stmt = conn.prepareStatement(query);
stmt.setString(1, userId);

// ❌ 命令注入
Runtime.getRuntime().exec("rm " + userInput);

// ✅ 使用 ProcessBuilder 并转义参数
ProcessBuilder pb = new ProcessBuilder("rm", sanitizedPath);

// ❌ 不安全的反序列化
ObjectInputStream ois = new ObjectInputStream(input);
Object obj = ois.readObject();

// ✅ 使用 JSON/XML 或配置反序列化过滤器
ObjectInputFilter filter = ObjectInputFilter.Config.createFilter("!*");
ois.setObjectInputFilter(filter);
```

### 资源泄漏

```java
// ❌ 未关闭资源
Connection conn = DriverManager.getConnection(url);
Statement stmt = conn.createStatement();
// 如果异常，资源不会关闭

// ✅ 使用 try-with-resources
try (Connection conn = DriverManager.getConnection(url);
     Statement stmt = conn.createStatement()) {
    // 使用资源
}

// ❌ 连接池泄漏
Connection conn = dataSource.getConnection();
// 忘记关闭

// ✅ 始终关闭
try (Connection conn = dataSource.getConnection()) {
    // 使用连接
}
```

### 空指针问题

```java
// ❌ 可能的 NPE
String name = user.getName().toUpperCase();

// ✅ 空值检查
String name = user.getName() != null ? user.getName().toUpperCase() : "";

// ✅ 使用 Optional (Java 8+)
String name = Optional.ofNullable(user.getName())
    .map(String::toUpperCase)
    .orElse("");

// ❌ 自动拆箱 NPE
Integer count = getCount();
int total = count + 1;  // count 为 null 时 NPE

// ✅ 显式处理
int total = (count != null ? count : 0) + 1;
```

### 并发问题

```java
// ❌ 非线程安全的单例
public class Singleton {
    private static Singleton instance;
    public static Singleton getInstance() {
        if (instance == null) {
            instance = new Singleton();
        }
        return instance;
    }
}

// ✅ 线程安全的实现
public class Singleton {
    private static volatile Singleton instance;
    public static Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}

// ✅ 或使用 enum
public enum Singleton {
    INSTANCE;
}
```

---

## Java 特有检查点

### 异常处理

```java
// ❌ 吞掉异常
try {
    doSomething();
} catch (Exception e) {
    // 什么都不做
}

// ✅ 记录或重新抛出
try {
    doSomething();
} catch (Exception e) {
    logger.error("操作失败", e);
    throw new BusinessException("操作失败", e);
}
```

### 字符串处理

```java
// ❌ 字符串比较错误
if (str == "hello") { }

// ✅ 使用 equals
if ("hello".equals(str)) { }

// ❌ 循环中拼接字符串
String result = "";
for (String s : list) {
    result += s;
}

// ✅ 使用 StringBuilder
StringBuilder sb = new StringBuilder();
for (String s : list) {
    sb.append(s);
}
String result = sb.toString();
```

### 集合使用

```java
// ❌ 暴露内部可变集合
public List<String> getItems() {
    return items;
}

// ✅ 返回不可修改视图
public List<String> getItems() {
    return Collections.unmodifiableList(items);
}

// ❌ 使用原始类型
List list = new ArrayList();

// ✅ 使用泛型
List<String> list = new ArrayList<>();
```

---

## 检查清单

```
□ SQL 查询使用 PreparedStatement
□ 所有资源使用 try-with-resources 关闭
□ 字符串比较使用 equals() 而非 ==
□ 空值检查或使用 Optional
□ 集合使用泛型
□ 不暴露内部可变集合
□ 异常正确处理，不吞掉
□ 单例模式线程安全
□ 避免在循环中拼接字符串
□ 避免自动拆箱导致的 NPE
```

---

## 工具推荐

```bash
# 静态分析
spotbugs
pmd

# 代码质量
sonarqube

# 安全检查
dependency-check

# IDE 插件
IntelliJ IDEA 内置检查
```