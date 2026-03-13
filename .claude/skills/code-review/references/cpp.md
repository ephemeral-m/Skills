# C/C++17 代码审查指南

## 常见问题检查

### 内存安全

```cpp
// ❌ 缓冲区溢出
char buffer[10];
strcpy(buffer, input);  // 无边界检查

// ✅ 安全替代
char buffer[10];
strncpy(buffer, input, sizeof(buffer) - 1);
buffer[sizeof(buffer) - 1] = '\0';

// ❌ 越界访问
int arr[10];
arr[10] = 0;  // 越界

// ✅ 使用 std::array 和 at()
std::array<int, 10> arr;
arr.at(9) = 0;  // 有边界检查

// ❌ 内存泄漏
int* ptr = new int(42);
// 忘记 delete

// ✅ 使用智能指针
auto ptr = std::make_unique<int>(42);
```

### 未定义行为

```cpp
// ❌ 未初始化变量
int count;
for (int i = 0; i < n; ++i) {
    count++;  // 未定义行为
}

// ✅ 初始化变量
int count = 0;

// ❌ 返回局部变量引用
int& get_value() {
    int x = 42;
    return x;  // 悬空引用
}

// ✅ 返回值
int get_value() {
    return 42;
}

// ❌ 悬空指针
std::vector<int> vec = {1, 2, 3};
int* ptr = &vec[0];
vec.push_back(4);  // 可能重新分配
*ptr = 0;  // 悬空指针

// ✅ 不保存指针
auto it = vec.begin();
// 或在修改后重新获取
```

### 资源管理

```cpp
// ❌ 手动管理资源
FILE* f = fopen("file.txt", "r");
// ... 可能提前返回
fclose(f);

// ✅ 使用 RAII
std::ifstream f("file.txt");

// ❌ 异常不安全
int* data = new int[100];
process(data);  // 可能抛异常，内存泄漏
delete[] data;

// ✅ 异常安全
auto data = std::make_unique<int[]>(100);
process(data.get());  // 异常时自动释放
```

### 并发问题

```cpp
// ❌ 数据竞争
int counter = 0;
void increment() {
    counter++;  // 非原子操作
}

// ✅ 使用原子或互斥
std::atomic<int> counter{0};
void increment() {
    counter++;
}

// ❌ 死锁
std::mutex m1, m2;
void f1() { std::lock_guard<std::mutex> l1(m1), l2(m2); }
void f2() { std::lock_guard<std::mutex> l1(m2), l1(m1); }

// ✅ 使用 std::lock
std::scoped_lock lock(m1, m2);  // C++17
```

---

## C++17 特有检查点

### 现代替代方案

```cpp
// ❌ 使用裸指针
Widget* w = new Widget();
delete w;

// ✅ 使用智能指针
auto w = std::make_unique<Widget>();

// ❌ 使用宏
#define MAX_SIZE 100

// ✅ 使用 constexpr
constexpr int MAX_SIZE = 100;

// ❌ 返回指针表示可空
Widget* find(int id);

// ✅ 使用 std::optional
std::optional<Widget> find(int id);

// ❌ 使用裸数组
int arr[100];

// ✅ 使用 std::array
std::array<int, 100> arr;
```

### 类型安全

```cpp
// ❌ C 风格转换
int i = (int)ptr;

// ✅ C++ 风格转换
int i = static_cast<int>(reinterpret_cast<intptr_t>(ptr));

// ❌ 隐式转换
void f(int x);
f(3.14);  // 隐式转换

// ✅ 显式转换或使用 = delete
void f(int x);
void f(double) = delete;
```

---

## 检查清单

```
□ 数组访问使用 at() 或检查边界
□ 所有动态内存使用智能指针
□ 变量初始化
□ 不返回局部变量引用
□ 使用 RAII 管理资源
□ 检查迭代器失效
□ 多线程访问使用原子或互斥
□ 避免 C 风格转换
□ 使用 constexpr 替代宏
□ 考虑使用 std::optional 表示可空值
□ 使用 std::string_view 避免字符串拷贝
```

---

## 工具推荐

```bash
# 静态分析
clang-tidy --checks='*'
cppcheck --enable=all

# 内存检测
valgrind --leak-check=full
AddressSanitizer: -fsanitize=address

# UB 检测
UBSanitizer: -fsanitize=undefined

# 现代 C++ 检查
clang-tidy -checks='modernize-*'
```