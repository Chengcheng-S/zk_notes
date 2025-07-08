# 快速开始指南

## 🎯 目标

本指南将帮助您在 10 分钟内在 Mac 上搭建 GPU 加速的 ZKP 计算环境。

## 📋 前置条件

### 硬件要求
- **推荐**: Apple Silicon Mac (M1/M2/M3)
- **最低**: Intel Mac with dedicated GPU (支持 Metal 2.0+)
- **内存**: 8GB+ RAM (推荐 16GB+)

### 软件要求
- macOS 12.0+ (推荐 macOS 13.0+)
- Xcode 14.0+ (包含 Metal 工具)
- Python 3.8+ (可选)

## 🚀 快速安装

### 1. 检查系统兼容性

```bash
# 检查 Metal 支持
system_profiler SPDisplaysDataType | grep "Metal"

# 检查 macOS 版本
sw_vers
```

### 2. 安装开发工具

```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 验证安装
metal --version
```

### 3. 克隆项目

```bash
git clone <your-repo-url>
cd gpu-for-mac
```

## 🛠️ Swift 框架设置

### 1. 构建 Swift 框架

```bash
cd swift-framework
swift build -c release
```

### 2. 运行测试

```bash
swift test
```

### 3. 第一个 Swift 示例

创建 `hello-zkp.swift`:

```swift
import Foundation
import ZKPMetal

// 检查 Metal 可用性
guard let device = MTLCreateSystemDefaultDevice() else {
    print("❌ Metal 不可用")
    exit(1)
}

print("✅ Metal 设备: \(device.name)")

// 初始化 ZKP 引擎
let engine = ZKPMetalEngine()

// 简单的 NTT 测试
let input: [UInt64] = [1, 2, 3, 4, 0, 0, 0, 0]
print("输入: \(input)")

if let result = engine.ntt(input) {
    print("NTT 结果: \(result)")
    
    // 验证逆变换
    if let recovered = engine.intt(result) {
        print("恢复: \(recovered)")
        print(recovered == input ? "✅ 测试通过" : "❌ 测试失败")
    }
} else {
    print("❌ NTT 计算失败")
}
```

运行示例:

```bash
swift hello-zkp.swift
```

## 🐍 Python 集成设置

### 1. 安装 Python 依赖

```bash
cd python-bindings
pip install -e .
```

### 2. 第一个 Python 示例

创建 `hello_zkp.py`:

```python
import zkp_metal
import numpy as np

# 检查 Metal 可用性
if not zkp_metal.is_metal_available():
    print("❌ Metal 不可用")
    exit(1)

print("✅ Metal 可用")

# 初始化引擎
engine = zkp_metal.MetalEngine()

# NTT 测试
input_data = [1, 2, 3, 4, 0, 0, 0, 0]
print(f"输入: {input_data}")

ntt_result = engine.ntt(input_data)
print(f"NTT 结果: {ntt_result}")

# 验证逆变换
recovered = engine.intt(ntt_result)
print(f"恢复: {recovered}")

if np.allclose(input_data, recovered):
    print("✅ 测试通过")
else:
    print("❌ 测试失败")
```

运行示例:

```bash
python hello_zkp.py
```

## 📊 性能基准测试

### 运行基础基准测试

```bash
cd benchmarks
python run_benchmarks.py
```

预期输出:

```
🚀 ZKP GPU 基准测试 - Apple M2 Pro

算法: NTT
大小        CPU时间     GPU时间     加速比
1024       2.3ms       0.8ms       2.9x
4096       9.1ms       1.5ms       6.1x
16384      38.2ms      5.2ms       7.3x
65536      156.8ms     18.9ms      8.3x

算法: MSM
大小        CPU时间     GPU时间     加速比
256        45.2ms      12.1ms      3.7x
1024       182.7ms     28.4ms      6.4x
4096       731.5ms     89.2ms      8.2x

✅ 所有测试通过
```

## 🔧 常见问题排除

### Metal 不可用

**问题**: `Metal 不可用` 错误

**解决方案**:
1. 检查硬件支持: `system_profiler SPDisplaysDataType`
2. 更新 macOS 到最新版本
3. 重新安装 Xcode

### 编译错误

**问题**: Swift 编译失败

**解决方案**:
1. 确保 Xcode 版本 >= 14.0
2. 清理构建缓存: `swift package clean`
3. 重新构建: `swift build -c release`

### Python 导入错误

**问题**: `import zkp_metal` 失败

**解决方案**:
1. 确保在正确的虚拟环境中
2. 重新安装: `pip uninstall zkp_metal && pip install -e .`
3. 检查 Python 版本 >= 3.8

### 性能不佳

**问题**: GPU 加速效果不明显

**解决方案**:
1. 检查输入数据大小 (太小的数据 GPU 优势不明显)
2. 监控 GPU 使用率: `sudo powermetrics -s gpu_power`
3. 查看内存使用: Activity Monitor -> GPU 标签

## 📚 下一步

### 学习路径

1. **基础概念**: 阅读 [Metal 编程指南](metal-programming.md)
2. **算法深入**: 探索 [NTT 实现](../metal-shaders/ntt/)
3. **性能优化**: 学习 [优化技巧](optimization-guide.md)
4. **实际应用**: 查看 [示例项目](../swift-framework/Examples/)

### 推荐实验

1. **修改 NTT 大小**: 尝试不同的输入大小
2. **比较不同算法**: 测试 FFT vs NTT 性能
3. **内存使用分析**: 使用 Instruments 分析内存
4. **功耗测试**: 比较 CPU vs GPU 功耗

## 🆘 获取帮助

- **文档**: 查看 [docs/](../docs/) 目录
- **示例**: 参考 [Examples/](../swift-framework/Examples/)
- **问题**: 提交 [GitHub Issue](../../issues)
- **讨论**: 参与 [GitHub Discussions](../../discussions)

---

**恭喜！您已经成功设置了 Mac GPU ZKP 计算环境！** 🎉