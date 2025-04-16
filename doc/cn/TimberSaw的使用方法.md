TimberSaw
=======

_Jeff Dean, Sanjay Ghemawat_

TimberSaw库提供了一个持久化键值存储。键和值都可以是任意的字节数组。键在键值存储中根据用户指定的
比较器函数进行排序。

## 打开数据库

TimberSaw数据库有一个对应于文件系统目录的名称。数据库的所有内容都存储在这个目录中。
以下示例展示了如何打开数据库，如果数据库不存在则创建它：

```c++
#include <cassert>
#include "TimberSaw/db.h"

TimberSaw::DB* db;
TimberSaw::Options options;
options.create_if_missing = true;
TimberSaw::Status status = TimberSaw::DB::Open(options, "/tmp/testdb", &db);
assert(status.ok());
...
```

如果你想在数据库已存在时引发错误，在`TimberSaw::DB::Open`调用之前添加以下行：

```c++
options.error_if_exists = true;
```

## 状态

你可能已经注意到上面的`TimberSaw::Status`类型。TimberSaw中可能遇到错误的大多数函数都会返回这种类型的值。
你可以检查这样的结果是否正常，也可以打印相关的错误消息：

```c++
TimberSaw::Status s = ...;
if (!s.ok()) cerr << s.ToString() << endl;
```

## 关闭数据库

当你使用完数据库后，只需删除数据库对象即可。示例：

```c++
... 如上所述打开数据库 ...
... 对数据库进行一些操作 ...
delete db;
```

## 读写操作

数据库提供Put、Delete和Get方法来修改/查询数据库。例如，以下代码将存储在key1下的值移动到key2：

```c++
std::string value;
TimberSaw::Status s = db->Get(TimberSaw::ReadOptions(), key1, &value);
if (s.ok()) s = db->Put(TimberSaw::WriteOptions(), key2, value);
if (s.ok()) s = db->Delete(TimberSaw::WriteOptions(), key1);
```

## 迭代

以下示例演示如何打印数据库中的所有键值对：

```c++
TimberSaw::Iterator* it = db->NewIterator(TimberSaw::ReadOptions());
for (it->SeekToFirst(); it->Valid(); it->Next()) {
  cout << it->key().ToString() << ": "  << it->value().ToString() << endl;
}
assert(it->status().ok());  // 检查扫描过程中是否发现任何错误
delete it;
```

以下变体展示了如何仅处理[start,limit)范围内的键：

```c++
for (it->Seek(start);
   it->Valid() && it->key().ToString() < limit;
   it->Next()) {
  ...
}
```

你也可以按相反顺序处理条目。（注意：反向迭代可能比正向迭代稍慢。）

```c++
for (it->SeekToLast(); it->Valid(); it->Prev()) {
  ...
}
```

## 快照

快照提供了对键值存储整个状态的一致性只读视图。`ReadOptions::snapshot`可以是非NULL值，
表示读取操作应该在数据库状态的特定版本上进行。如果`ReadOptions::snapshot`为NULL，
读取操作将在当前状态的隐式快照上进行。

快照通过`DB::GetSnapshot()`方法创建：

```c++
TimberSaw::ReadOptions options;
options.snapshot = db->GetSnapshot();
... 对数据库应用一些更新 ...
TimberSaw::Iterator* iter = db->NewIterator(options);
... 使用迭代器查看创建快照时的状态 ...
delete iter;
db->ReleaseSnapshot(options.snapshot);
```

注意，当不再需要快照时，应该使用`DB::ReleaseSnapshot`接口释放它。这允许实现清理仅用于支持该快照读取的状态。

## Slice

上面的`it->key()`和`it->value()`调用的返回值是`TimberSaw::Slice`类型的实例。Slice是一个简单的结构，
包含一个长度和一个指向外部字节数组的指针。返回Slice比返回`std::string`更高效，因为我们不需要复制
可能很大的键和值。此外，TimberSaw方法不返回以null结尾的C风格字符串，因为TimberSaw的键和值允许包含`'\0'`字节。

C++字符串和以null结尾的C风格字符串可以轻松转换为Slice：

```c++
TimberSaw::Slice s1 = "hello";

std::string str("world");
TimberSaw::Slice s2 = str;
```

Slice可以轻松转换回C++字符串：

```c++
std::string str = s1.ToString();
assert(str == std::string("hello"));
```

使用Slice时要小心，因为调用者需要确保Slice指向的外部字节数组在Slice使用期间保持有效。
例如，以下代码有bug：

```c++
TimberSaw::Slice slice;
if (...) {
  std::string str = ...;
  slice = str;
}
Use(slice);
```

当if语句超出作用域时，str将被销毁，slice的后备存储将消失。

## 比较器

前面的示例使用了键的默认排序函数，它按字典序排序字节。但是，你可以在打开数据库时提供自定义比较器。
例如，假设每个数据库键由两个数字组成，我们应该按第一个数字排序，如果相同则按第二个数字排序。
首先，定义一个表达这些规则的`TimberSaw::Comparator`的适当子类：

```c++
class TwoPartComparator : public TimberSaw::Comparator {
 public:
  // 三路比较函数：
  //   如果 a < b：负结果
  //   如果 a > b：正结果
  //   否则：零结果
  int Compare(const TimberSaw::Slice& a, const TimberSaw::Slice& b) const {
    int a1, a2, b1, b2;
    ParseKey(a, &a1, &a2);
    ParseKey(b, &b1, &b2);
    if (a1 < b1) return -1;
    if (a1 > b1) return +1;
    if (a2 < b2) return -1;
    if (a2 > b2) return +1;
    return 0;
  }

  // 暂时忽略以下方法：
  const char* Name() const { return "TwoPartComparator"; }
  void FindShortestSeparator(std::string*, const TimberSaw::Slice&) const {}
  void FindShortSuccessor(std::string*) const {}
};
```

现在使用这个自定义比较器创建数据库：

```c++
TwoPartComparator cmp;
TimberSaw::DB* db;
TimberSaw::Options options;
options.create_if_missing = true;
options.comparator = &cmp;
TimberSaw::Status status = TimberSaw::DB::Open(options, "/tmp/testdb", &db);
...
```

### 向后兼容性

比较器的Name方法的结果在创建数据库时附加到数据库，并在每次后续打开数据库时检查。如果名称发生变化，
`TimberSaw::DB::Open`调用将失败。因此，仅当新的键格式和比较函数与现有数据库不兼容，
且可以丢弃所有现有数据库的内容时，才更改名称。

但是，通过一些预先规划，你仍然可以随时间逐步发展你的键格式。例如，你可以在每个键的末尾存储一个版本号
（对于大多数用途来说一个字节就足够了）。当你想切换到新的键格式时（例如，向`TwoPartComparator`处理的键
添加可选的第三部分），(a)保持相同的比较器名称 (b)为新键增加版本号 (c)更改比较器函数，
使其使用键中的版本号来决定如何解释它们。

## 性能

可以通过更改`include/options.h`中定义的类型的默认值来调整性能。

### 块大小

TimberSaw将相邻的键组合到同一个块中，这样的块是与持久存储之间传输的单位。默认块大小约为4096个未压缩字节。
主要对数据库内容进行批量扫描的应用可能希望增加这个大小。对小值进行大量点读取的应用如果性能测量表明有改进，
可能希望切换到更小的块大小。使用小于一千字节或大于几兆字节的块没有太多好处。另外请注意，
使用更大的块大小压缩效果会更好。

### 压缩

每个块在写入持久存储之前都会单独压缩。压缩默认是开启的，因为默认压缩方法非常快，
并且对于不可压缩的数据会自动禁用。在极少数情况下，应用可能想要完全禁用压缩，
但只有在基准测试显示性能改进时才应这样做：

```c++
TimberSaw::Options options;
options.compression = TimberSaw::kNoCompression;
... TimberSaw::DB::Open(options, name, ...) ....
```

### 缓存

数据库的内容存储在文件系统的一组文件中，每个文件存储一系列压缩块。如果options.block_cache非NULL，
它用于缓存经常使用的未压缩块内容。

```c++
#include "TimberSaw/cache.h"

TimberSaw::Options options;
options.block_cache = TimberSaw::NewLRUCache(100 * 1048576);  // 100MB缓存
TimberSaw::DB* db;
TimberSaw::DB::Open(options, name, &db);
... 使用数据库 ...
delete db
delete options.block_cache;
```

注意，缓存保存未压缩的数据，因此应该根据应用层数据大小来设置其大小，而不考虑压缩带来的减少。
（压缩块的缓存留给操作系统缓冲区缓存，或客户端提供的任何自定义Env实现。）

执行批量读取时，应用可能希望禁用缓存，这样批量读取处理的数据就不会替换大部分缓存内容。
可以使用每个迭代器的选项来实现这一点：

```c++
TimberSaw::ReadOptions options;
options.fill_cache = false;
TimberSaw::Iterator* it = db->NewIterator(options);
for (it->SeekToFirst(); it->Valid(); it->Next()) {
  ...
}
```

### 键布局

注意，磁盘传输和缓存的单位是块。相邻的键（根据数据库排序顺序）通常会放在同一个块中。
因此，应用可以通过将经常一起访问的键放在彼此附近，并将不常使用的键放在键空间的单独区域来提高其性能。

例如，假设我们在TimberSaw之上实现一个简单的文件系统。我们可能希望存储的条目类型是：

    filename -> permission-bits, length, list of file_block_ids
    file_block_id -> data

我们可能想用一个字母（比如'/'）作为filename键的前缀，用另一个字母（比如'0'）作为`file_block_id`键的前缀，
这样仅对元数据的扫描就不会强制我们获取和缓存大量的文件内容。

### 过滤器

由于TimberSaw数据在磁盘上的组织方式，单个`Get()`调用可能涉及多次磁盘读取。可选的FilterPolicy机制
可以用来大幅减少磁盘读取次数。

```c++
TimberSaw::Options options;
options.filter_policy = NewBloomFilterPolicy(10);
TimberSaw::DB* db;
TimberSaw::DB::Open(options, "/tmp/testdb", &db);
... 使用数据库 ...
delete db;
delete options.filter_policy;
```

上述代码将基于布隆过滤器的过滤策略与数据库关联。基于布隆过滤器的过滤依赖于在内存中为每个键保存一定数量的
数据位（在这种情况下是每个键10位，因为这是我们传递给`NewBloomFilterPolicy`的参数）。这个过滤器将把Get()
调用所需的不必要磁盘读取次数减少大约100倍。增加每个键的位数将以更多内存使用为代价带来更大的减少。
我们建议工作集不适合内存且进行大量随机读取的应用设置过滤策略。

如果你使用自定义比较器，你应该确保你使用的过滤策略与你的比较器兼容。例如，考虑一个在比较键时忽略尾随空格的
比较器。`NewBloomFilterPolicy`不能与这样的比较器一起使用。相反，应用应该提供一个也忽略尾随空格的自定义
过滤策略。例如：

```c++
class CustomFilterPolicy : public TimberSaw::FilterPolicy {
 private:
  FilterPolicy* builtin_policy_;

 public:
  CustomFilterPolicy() : builtin_policy_(NewBloomFilterPolicy(10)) {}
  ~CustomFilterPolicy() { delete builtin_policy_; }

  const char* Name() const { return "IgnoreTrailingSpacesFilter"; }

  void CreateFilter(const Slice* keys, int n, std::string* dst) const {
    // 在移除尾随空格后使用内置布隆过滤器代码
    std::vector<Slice> trimmed(n);
    for (int i = 0; i < n; i++) {
      trimmed[i] = RemoveTrailingSpaces(keys[i]);
    }
    return builtin_policy_->CreateFilter(trimmed.data(), n, dst);
  }
};
```

高级应用可能提供一个不使用布隆过滤器而使用其他机制来汇总一组键的过滤策略。详见`TimberSaw/filter_policy.h`。

## 校验和

TimberSaw将校验和与它存储在文件系统中的所有数据关联。对这些校验和的验证程度有两个独立的控制：

`ReadOptions::verify_checksums`可以设置为true，以强制验证代表特定读取的所有从文件系统读取的数据的校验和。
默认情况下，不进行这样的验证。

`Options::paranoid_checks`可以在打开数据库之前设置为true，使数据库实现在检测到内部损坏时立即引发错误。
根据数据库的哪个部分被损坏，错误可能在数据库打开时引发，或者在后续的数据库操作中引发。默认情况下，
偏执检查是关闭的，这样即使持久存储的部分被损坏，数据库仍然可以使用。

如果数据库损坏（可能在打开时偏执检查开启时无法打开），可以使用`TimberSaw::RepairDB`函数来恢复尽可能多的数据。

## 近似大小

`GetApproximateSizes`方法可用于获取一个或多个键范围使用的文件系统空间的近似字节数。

```c++
TimberSaw::Range ranges[2];
ranges[0] = TimberSaw::Range("a", "c");
ranges[1] = TimberSaw::Range("x", "z");
uint64_t sizes[2];
db->GetApproximateSizes(ranges, 2, sizes);
```

上述调用将设置`sizes[0]`为键范围`[a..c)`使用的文件系统空间的近似字节数，
设置`sizes[1]`为键范围`[x..z)`使用的近似字节数。

## 环境

TimberSaw实现发出的所有文件操作（和其他操作系统调用）都通过`TimberSaw::Env`对象路由。
复杂的客户端可能希望提供自己的Env实现以获得更好的控制。例如，应用可能在文件IO路径中引入人为延迟，
以限制TimberSaw对系统中其他活动的影响。

```c++
class SlowEnv : public TimberSaw::Env {
  ... Env接口的实现 ...
};

SlowEnv env;
TimberSaw::Options options;
options.env = &env;
Status s = TimberSaw::DB::Open(options, ...);
```

## 移植

通过为`TimberSaw/port/port.h`导出的类型/方法/函数提供平台特定的实现，TimberSaw可以移植到新平台。
更多详情请参见`TimberSaw/port/port_example.h`。

此外，新平台可能需要新的默认`TimberSaw::Env`实现。参见`TimberSaw/util/env_posix.h`作为示例。

## 其他信息

有关TimberSaw实现的详细信息可以在以下文档中找到：

1. [实现说明](impl-cn.md)
2. [不可变表文件的格式](table_format-cn.md)
3. [日志文件的格式](log_format-cn.md) 