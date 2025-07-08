# 🚀 快速开始指南

欢迎使用 GPU for Mac ZKP 计算库！这个指南将帮助你在几分钟内开始使用。

## 📋 系统要求

- **操作系统**: macOS 10.15+ (推荐 macOS 12.0+)
- **Python**: 3.8+ 
- **硬件**: 支持 Metal 的 Mac (2012年后的大部分 Mac)
- **工具**: Xcode Command Line Tools

## ⚡ 一键安装

```bash
# 克隆项目
git clone https://github.com/gpu-for-mac/zkp-computations.git
cd zkp-computations

# 运行自动安装脚本
chmod +x install.sh
./install.sh

# 或者使用 Make
make install
```

## 🎯 快速验证

安装完成后，运行以下命令验证安装：

```bash
# 激活虚拟环境
source venv/bin/activate

# 运行简单示例
python simple-proof/simple_zkp_example.py

# 运行快速基准测试
python benchmarks/comprehensive_benchmark.py --quick
```

## 📊 预期输出

### 简单 ZKP 示例
```
🚀 简单零知识证明演示 - Mac GPU 加速
============================================================
✅ 使用 Metal 设备: Apple M2

🔐 生成零知识证明...
秘密值: 123
公开值: 15129
模数: 2147483647
随机数 r: 1234567
承诺值: 1524157875
GPU 计算耗时: 0.15 ms
挑战值: 12345
响应: 152415787 (类型: r*secret)

🔍 验证零知识证明...
承诺值: 1524157875
挑战值: 12345
响应: 152415787
响应类型: r*secret
验证: 152415787^2 mod 2147483647 = 1234567890
期望: 1524157875 * 15129 mod 2147483647 = 1234567890
结果: ✅ 验证通过

🎉 零知识证明演示成功！
```

### 基准测试结果
```
📊 GPU vs CPU 性能对比
==================================================
测试大小: 1000
GPU 计算:
GPU 计算耗时: 0.85 ms
CPU 计算:
CPU 计算耗时: 12.34 ms
✅ GPU 和 CPU 结果一致

📋 基准测试摘要
================================================================================
系统: macOS-13.0-arm64-arm-64bit
CPU: Apple M2
内存: 16 GB
GPU: Apple M2
GPU 峰值性能: 1234.5 GFLOPS
CPU 峰值性能: 89.2 GFLOPS
内存带宽峰值: 45678.9 MB/s
```

## 🛠️ 常用命令

```bash
# 查看所有可用命令
make help

# 运行完整基准测试
make benchmark

# 运行快速基准测试  
make benchmark-quick

# 运行演示
make demo

# 编译 Metal 着色器
make metal

# 查看系统信息
make info

# 清理项目
make clean
```

## 📚 下一步

1. **阅读文档**: 
   - [Metal 编程指南](docs/metal-programming.md)
   - [优化技巧](docs/optimization-tips.md)
   - [故障排除](docs/troubleshooting.md)

2. **探索示例**:
   - `simple-proof/` - 简单的零知识证明示例
   - `benchmarks/` - 性能基准测试
   - `metal-shaders/` - Metal 着色器代码

3. **自定义开发**:
   - 修改 `metal-shaders/` 中的着色器
   - 在 `benchmarks/` 中添加新的测试
   - 创建自己的 ZKP 应用

## 🔧 开发模式

如果你想参与开发或修改代码：

```bash
# 安装开发依赖
./install.sh --dev
# 或
make install-dev

# 代码格式化
make format

# 代码检查
make lint

# 运行测试
make test
```

## ❓ 遇到问题？

1. **检查系统要求**: 确保你的 Mac 支持 Metal
2. **查看故障排除指南**: [docs/troubleshooting.md](docs/troubleshooting.md)
3. **运行系统信息检查**: `make info`
4. **提交 Issue**: [GitHub Issues](https://github.com/gpu-for-mac/zkp-computations/issues)

## 🎉 成功！

如果你看到了预期的输出，恭喜！你已经成功安装并运行了 GPU for Mac ZKP 计算库。

现在你可以：
- 🔬 探索更多示例和文档
- ⚡ 在你的项目中使用 GPU 加速的 ZKP 计算
- 🚀 为项目贡献代码和改进

Happy coding! 🎊