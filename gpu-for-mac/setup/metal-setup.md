# Metal 环境配置指南

## 概述

本指南帮助您在 macOS 上设置 Metal 开发环境，用于 ZKP 计算加速。

## 系统检查

### 1. 检查 Metal 支持

```bash
# 检查系统信息
system_profiler SPDisplaysDataType | grep "Metal"

# 或使用 Swift 检查
swift -e "import Metal; print(MTLCreateSystemDefaultDevice() != nil ? \"Metal 支持\" : \"Metal 不支持\")"
```

### 2. 硬件兼容性

| Mac 型号 | Metal 版本 | ZKP 性能 | 推荐度 |
|---------|-----------|---------|--------|
| M3 Pro/Max | Metal 3 | 优秀 | ⭐⭐⭐⭐⭐ |
| M2 Pro/Max | Metal 3 | 很好 | ⭐⭐⭐⭐⭐ |
| M1 Pro/Max | Metal 3 | 很好 | ⭐⭐⭐⭐ |
| M1/M2 | Metal 3 | 良好 | ⭐⭐⭐ |
| Intel + AMD | Metal 2.4 | 一般 | ⭐⭐ |

## 开发环境安装

### 1. Xcode 安装

```bash
# 从 App Store 安装 Xcode
# 或使用命令行工具
xcode-select --install
```

### 2. Swift Package Manager 设置

创建 `Package.swift`:

```swift
// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "ZKPMetal",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .library(name: "ZKPMetal", targets: ["ZKPMetal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "ZKPMetal",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .testTarget(
            name: "ZKPMetalTests",
            dependencies: ["ZKPMetal"]
        ),
    ]
)
```

### 3. Python 集成 (可选)

```bash
# 安装 PyObjC 用于 Python-Metal 桥接
pip install pyobjc-framework-Metal
pip install pyobjc-framework-MetalPerformanceShaders

# 安装数值计算库
pip install numpy scipy
```

## 基础测试

### 1. Metal 设备测试

```swift
import Metal

func testMetalDevice() {
    guard let device = MTLCreateSystemDefaultDevice() else {
        print("Metal 不可用")
        return
    }
    
    print("Metal 设备: \(device.name)")
    print("最大线程组大小: \(device.maxThreadsPerThreadgroup)")
    print("最大缓冲区长度: \(device.maxBufferLength)")
    print("支持的 Metal 版本: \(device.supportsFamily(.apple7) ? "Apple7+" : "较低版本")")
}
```

### 2. 简单计算测试

```swift
import Metal

class MetalCompute {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
    }
    
    func vectorAdd(_ a: [Float], _ b: [Float]) -> [Float]? {
        let count = min(a.count, b.count)
        
        // 创建缓冲区
        guard let bufferA = device.makeBuffer(bytes: a, length: count * MemoryLayout<Float>.size),
              let bufferB = device.makeBuffer(bytes: b, length: count * MemoryLayout<Float>.size),
              let bufferResult = device.makeBuffer(length: count * MemoryLayout<Float>.size) else {
            return nil
        }
        
        // 这里需要添加 Metal 着色器代码
        // 简化示例，实际需要编译着色器
        
        return Array(repeating: 0.0, count: count)
    }
}
```

## 性能调优

### 1. 内存管理

```swift
// 使用共享内存减少数据传输
let buffer = device.makeBuffer(
    length: dataSize,
    options: [.storageModeShared]
)

// 批量操作减少 GPU 调用
let commandBuffer = commandQueue.makeCommandBuffer()
// 添加多个计算操作
commandBuffer?.commit()
```

### 2. 线程组优化

```swift
// 根据硬件特性调整线程组大小
let threadsPerThreadgroup = MTLSize(
    width: min(1024, device.maxThreadsPerThreadgroup.width),
    height: 1,
    depth: 1
)

let threadgroupsPerGrid = MTLSize(
    width: (dataCount + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
    height: 1,
    depth: 1
)
```

## 故障排除

### 常见问题

1. **Metal 不可用**
   - 检查系统版本和硬件支持
   - 确保 Xcode 正确安装

2. **性能不佳**
   - 检查内存使用模式
   - 优化线程组大小
   - 减少 CPU-GPU 数据传输

3. **编译错误**
   - 检查 Metal 着色器语法
   - 确保目标平台正确

### 调试工具

```bash
# 使用 Instruments 进行性能分析
instruments -t "Metal System Trace" your_app

# GPU 使用情况监控
sudo powermetrics -s gpu_power -n 1
```

## 下一步

完成环境设置后，您可以：

1. 查看 [FFT/NTT GPU 实现](../algorithms/fft-ntt/)
2. 尝试 [简单证明示例](../examples/simple-proof/)
3. 阅读 [Metal 编程指南](../docs/metal-programming.md)