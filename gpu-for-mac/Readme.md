# GPU 加速 ZKP 计算 - Mac 平台指南

## 概述

本目录包含在 macOS 平台上使用 GPU 加速零知识证明计算的指南、工具和示例代码。

## 目录结构

```
gpu-for-mac/
├── README.md                    # 本文件
├── setup/                       # 环境设置指南
│   ├── metal-setup.md          # Metal 环境配置
│   ├── python-metal-bridge.md  # Python-Metal 集成
│   └── development-tools.md    # 开发工具推荐
├── algorithms/                  # GPU 优化算法实现
│   ├── fft-ntt/                # FFT/NTT GPU 实现
│   ├── msm/                    # 多标量乘法优化
│   ├── elliptic-curves/        # 椭圆曲线 GPU 运算
│   └── polynomial-ops/         # 多项式运算加速
├── frameworks/                  # 框架和库
│   ├── metal-zkp/              # Metal 基础 ZKP 库
│   ├── swift-crypto/           # Swift 密码学库集成
│   └── python-bindings/        # Python 绑定
├── benchmarks/                  # 性能测试
│   ├── cpu-vs-gpu/             # CPU vs GPU 性能对比
│   ├── memory-usage/           # 内存使用分析
│   └── power-efficiency/       # 功耗效率测试
├── examples/                    # 示例项目
│   ├── simple-proof/           # 简单证明生成
│   ├── circuit-compilation/    # 电路编译示例
│   └── real-world-apps/        # 实际应用案例
└── docs/                       # 详细文档
    ├── metal-programming.md    # Metal 编程指南
    ├── optimization-tips.md    # 优化技巧
    └── troubleshooting.md      # 故障排除
```

## 快速开始

### 系统要求
- macOS 10.15+ (推荐 macOS 12+)
- Apple Silicon (M1/M2/M3) 或 Intel Mac with dedicated GPU
- Xcode 12+ (用于 Metal 开发)
- Python 3.8+ (可选，用于 Python 集成)

### 安装步骤
1. 查看 [Metal 环境配置](setup/metal-setup.md)
2. 安装必要的开发工具
3. 运行基础性能测试
4. 探索示例项目

## 主要特性

### 🚀 性能优化
- **FFT/NTT 加速**: 利用 Metal 并行计算能力
- **MSM 优化**: 多标量乘法的 GPU 实现
- **内存管理**: 高效的 GPU 内存使用策略

### 🛠️ 开发工具
- **Metal Shaders**: 专门的 ZKP 计算着色器
- **Python 集成**: 无缝的 Python-Metal 桥接
- **性能分析**: 详细的基准测试工具

### 📚 学习资源
- **教程**: 从基础到高级的完整指南
- **示例代码**: 可运行的实际项目
- **最佳实践**: 经过验证的优化策略

## 性能预期

| 操作类型 | CPU (M2) | GPU (M2) | 加速比 |
|---------|----------|----------|--------|
| FFT (2^20) | 150ms | 25ms | 6x |
| MSM (2^16) | 800ms | 120ms | 6.7x |
| 椭圆曲线加法 | 50ms | 8ms | 6.25x |

*注：实际性能可能因具体硬件和实现而异*

## 贡献指南

欢迎贡献代码、文档或性能优化建议！请查看各子目录的具体说明。

## 许可证

本项目遵循 MIT 许可证。

## 相关资源

- [Apple Metal 官方文档](https://developer.apple.com/metal/)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [ZKP 基础数学知识](../protocol/basic-math/)