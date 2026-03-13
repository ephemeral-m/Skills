# C/C++17 重构指南

## 目录
- [特定重构技术](#特定重构技术)
- [代码示例](#代码示例)
- [工具推荐](#工具推荐)
- [常见陷阱](#常见陷阱)

---

## 特定重构技术

### 1. 用 auto 简化类型声明

```cpp
// 重构前
std::map<std::string, std::vector<int>>::iterator it = data.find(key);
std::vector<int>::const_iterator cit = values.begin();

// 重构后
auto it = data.find(key);
auto cit = values.cbegin();
```

### 2. 用结构化绑定 (C++17)

```cpp
// 重构前
std::pair<std::string, int> result = get_data();
std::string name = result.first;
int age = result.second;

// 重构后
auto [name, age] = get_data();
```

### 3. 用范围 for 替换索引循环

```cpp
// 重构前
for (size_t i = 0; i < items.size(); ++i) {
    process(items[i]);
}

// 重构后
for (const auto& item : items) {
    process(item);
}
```

### 4. 用 RAII 管理资源

```cpp
// 重构前
void process() {
    FILE* file = fopen("data.txt", "r");
    if (!file) return;

    // ... 可能提前返回的代码 ...

    fclose(file);  // 可能忘记
}

// 重构后
void process() {
    std::ifstream file("data.txt");
    if (!file) return;

    // 文件会在作用域结束时自动关闭
}
```

### 5. 用智能指针替换裸指针

```cpp
// 重构前
Widget* widget = new Widget();
// ... 使用 widget ...
delete widget;  // 可能忘记，或异常时泄漏

// 重构后
auto widget = std::make_unique<Widget>();
// 自动管理生命周期
```

### 6. 用 std::optional 表示可空值 (C++17)

```cpp
// 重构前
Widget* find_widget(int id) {
    auto it = widgets.find(id);
    if (it != widgets.end()) {
        return &it->second;
    }
    return nullptr;  // 需要检查 nullptr
}

// 重构后
std::optional<Widget> find_widget(int id) {
    auto it = widgets.find(id);
    if (it != widgets.end()) {
        return it->second;
    }
    return std::nullopt;
}

// 使用
if (auto widget = find_widget(42)) {
    use(*widget);
}
```

### 7. 用 constexpr 替换宏

```cpp
// 重构前
#define MAX_SIZE 100
#define SQUARE(x) ((x) * (x))

// 重构后
constexpr int MAX_SIZE = 100;
constexpr int square(int x) { return x * x; }
```

### 8. 用 lambda 简化算法

```cpp
// 重构前
struct IsEven {
    bool operator()(int n) const { return n % 2 == 0; }
};
std::vector<int> evens;
std::copy_if(nums.begin(), nums.end(), std::back_inserter(evens), IsEven());

// 重构后
std::vector<int> evens;
std::copy_if(nums.begin(), nums.end(), std::back_inserter(evens),
    [](int n) { return n % 2 == 0; });
```

### 9. 用 std::string_view 避免字符串拷贝 (C++17)

```cpp
// 重构前
void process(const std::string& str) {
    // 接受 string 或 const char*，但可能产生临时 string
}
process(std::string("hello"));  // 可能创建临时对象

// 重构后
void process(std::string_view str) {
    // 零拷贝，接受 string、const char* 或字面量
}
process("hello");  // 无拷贝
```

---

## 工具推荐

```bash
# 静态分析
clang-tidy main.cpp -- -std=c++17
cppcheck --enable=all main.cpp

# 代码格式化
clang-format -i main.cpp
# 配置文件: .clang-format

# 内存检测
valgrind --leak-check=full ./program
AddressSanitizer: -fsanitize=address

# 现代化检查
clang-tidy -checks='modernize-*' main.cpp
```

---

## 常见陷阱

### 迭代器失效
```cpp
// 错误
for (auto it = vec.begin(); it != vec.end(); ++it) {
    if (*it == target) {
        vec.erase(it);  // 迭代器失效！
    }
}

// 正确
for (auto it = vec.begin(); it != vec.end(); ) {
    if (*it == target) {
        it = vec.erase(it);
    } else {
        ++it;
    }
}
```

### 未初始化变量
```cpp
// 错误
int count;  // 未初始化
for (int i = 0; i < n; ++i) {
    count++;  // 不确定的行为
}

// 正确
int count = 0;
```

### 悬空引用
```cpp
// 错误
const int& get_value() {
    int x = 42;
    return x;  // 返回局部变量的引用
}

// 正确
int get_value() {
    return 42;
}
```