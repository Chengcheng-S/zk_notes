# 故障排除指南

## 概述

本指南帮助解决在 Mac 平台上开发和运行 GPU 加速 ZKP 计算时遇到的常见问题。

## 环境问题

### 1. Metal 不支持

**症状**：
```
Metal 不支持
MTLCreateSystemDefaultDevice() 返回 nil
```

**原因和解决方案**：

#### macOS 版本过低
```bash
# 检查 macOS 版本
sw_vers

# 解决方案：升级到 macOS 10.15+
# 推荐 macOS 12.0+ 以获得最佳性能
```

#### 虚拟机环境
```bash
# 检查是否在虚拟机中运行
system_profiler SPHardwareDataType | grep "Model Name"

# 虚拟机通常不支持 Metal
# 解决方案：在物理 Mac 上运行
```

#### 远程桌面连接
```bash
# 检查是否通过远程连接
who

# 解决方案：直接在本地运行，或使用 SSH 无图形界面模式
```

### 2. Xcode 和开发工具问题

**症状**：
```
xcrun: error: unable to find utility "metal"
Command Line Tools not found
```

**解决方案**：
```bash
# 安装 Xcode Command Line Tools
xcode-select --install

# 检查安装状态
xcode-select -p

# 如果路径不正确，重置
sudo xcode-select --reset

# 验证 Metal 编译器
xcrun -sdk macosx metal --version
```

### 3. Python 环境问题

**症状**：
```python
ModuleNotFoundError: No module named 'objc'
ImportError: cannot import name 'Metal' from 'Foundation'
```

**解决方案**：
```bash
# 安装 PyObjC
pip install pyobjc-framework-Metal
pip install pyobjc-framework-MetalKit

# 或安装完整的 PyObjC
pip install pyobjc

# 验证安装
python -c "import Metal; print('Metal 模块导入成功')"
```

## 编译问题

### 1. Metal 着色器编译错误

**症状**：
```
Metal Compile Error: use of undeclared identifier 'FieldElement'
Metal Compile Error: no matching function for call to 'field_add'
```

**解决方案**：

#### 检查头文件包含
```metal
// 确保包含必要的头文件
#include <metal_stdlib>
#include "field_arithmetic.h"  // 自定义头文件
using namespace metal;
```

#### 验证函数声明
```metal
// 确保函数在使用前已声明
FieldElement field_add(FieldElement a, FieldElement b);

// 或者在同一文件中定义
inline FieldElement field_add(FieldElement a, FieldElement b) {
    // 实现
}
```

#### 编译器标志
```swift
// 在 Swift 中设置编译选项
let library = try device.makeLibrary(source: shaderSource, options: {
    let options = MTLCompileOptions()
    options.fastMathEnabled = true
    options.languageVersion = .version2_4
    return options
}())
```

### 2. Swift 编译问题

**症状**：
```
'MTLBuffer' is not convertible to 'UnsafeMutablePointer<Float>'
Cannot convert value of type 'MTLDevice' to expected argument type 'MTLDevice?'
```

**解决方案**：

#### 类型转换
```swift
// 正确的缓冲区访问方式
let buffer = device.makeBuffer(length: size, options: .storageModeShared)!
let pointer = buffer.contents().bindMemory(to: Float.self, capacity: count)

// 错误的方式
// let pointer = buffer as! UnsafeMutablePointer<Float>  // 不要这样做
```

#### 可选值处理
```swift
// 使用 guard 语句处理可选值
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("Metal 设备创建失败")
}

guard let commandQueue = device.makeCommandQueue() else {
    fatalError("命令队列创建失败")
}
```

## 运行时问题

### 1. 内存不足

**症状**：
```
Metal Error: IOAF code 5 (resource shortage)
Memory allocation failed
```

**诊断**：
```swift
func diagnoseMemoryUsage(device: MTLDevice) {
    let allocated = device.currentAllocatedSize
    let recommended = device.recommendedMaxWorkingSetSize
    
    print("当前分配: \(allocated / 1024 / 1024) MB")
    print("推荐最大: \(recommended / 1024 / 1024) MB")
    print("使用率: \(Double(allocated) / Double(recommended) * 100)%")
    
    if allocated > recommended {
        print("⚠️  内存使用超过推荐值")
    }
}
```

**解决方案**：

#### 减少内存使用
```swift
// 1. 使用更小的数据类型
struct CompactFieldElement {
    var limbs: (UInt64, UInt64, UInt64, UInt64)  // 代替数组
}

// 2. 分批处理
func processBatches<T>(data: [T], batchSize: Int, processor: ([T]) -> Void) {
    for i in stride(from: 0, to: data.count, by: batchSize) {
        let end = min(i + batchSize, data.count)
        let batch = Array(data[i..<end])
        processor(batch)
    }
}

// 3. 及时释放缓冲区
func releaseBuffers() {
    // 显式设置为 nil 以触发释放
    largeBuffer = nil
    tempBuffers.removeAll()
}
```

#### 内存池优化
```swift
class MemoryPool {
    private var buffers: [Int: [MTLBuffer]] = [:]
    
    func getBuffer(size: Int, device: MTLDevice) -> MTLBuffer? {
        // 向上取整到最近的 2 的幂
        let alignedSize = nextPowerOfTwo(size)
        
        if let buffer = buffers[alignedSize]?.popLast() {
            return buffer
        }
        
        return device.makeBuffer(length: alignedSize, options: .storageModePrivate)
    }
    
    private func nextPowerOfTwo(_ n: Int) -> Int {
        guard n > 1 else { return 1 }
        return 1 << (Int(log2(Double(n - 1))) + 1)
    }
}
```

### 2. 性能问题

**症状**：
```
GPU 计算比 CPU 还慢
帧率下降
计算超时
```

**诊断工具**：

#### 性能分析器
```swift
class PerformanceProfiler {
    private var startTime: CFTimeInterval = 0
    
    func startTiming() {
        startTime = CACurrentMediaTime()
    }
    
    func endTiming(operation: String) -> Double {
        let endTime = CACurrentMediaTime()
        let duration = (endTime - startTime) * 1000  // 转换为毫秒
        print("\(operation): \(String(format: "%.2f", duration)) ms")
        return duration
    }
    
    func profileGPUMemoryBandwidth(device: MTLDevice) {
        let testSize = 64 * 1024 * 1024  // 64MB
        guard let buffer = device.makeBuffer(length: testSize, options: .storageModeShared) else {
            return
        }
        
        let iterations = 100
        startTiming()
        
        for _ in 0..<iterations {
            // 模拟内存访问
            let pointer = buffer.contents().bindMemory(to: UInt8.self, capacity: testSize)
            for i in 0..<testSize {
                pointer[i] = UInt8(i % 256)
            }
        }
        
        let duration = endTiming(operation: "内存带宽测试")
        let bandwidth = Double(testSize * iterations) / (duration / 1000) / (1024 * 1024)
        print("内存带宽: \(String(format: "%.2f", bandwidth)) MB/s")
    }
}
```

#### GPU 利用率检查
```swift
func checkGPUUtilization() {
    // 使用 Activity Monitor 或 iStat Menus 检查 GPU 使用率
    // 如果 GPU 使用率低，可能存在以下问题：
    
    // 1. 线程组配置不当
    let threadsPerThreadgroup = MTLSize(width: 256, height: 1, depth: 1)  // 尝试不同的值
    
    // 2. 内存访问模式不佳
    // 确保连续内存访问
    
    // 3. 计算强度不足
    // 增加每个线程的计算量
}
```

**解决方案**：

#### 优化线程配置
```swift
func optimizeThreadConfiguration(device: MTLDevice, 
                                computePipelineState: MTLComputePipelineState,
                                dataSize: Int) -> (MTLSize, MTLSize) {
    
    let maxThreadsPerThreadgroup = computePipelineState.maxTotalThreadsPerThreadgroup
    let threadExecutionWidth = computePipelineState.threadExecutionWidth
    
    // 选择线程组大小（应该是 threadExecutionWidth 的倍数）
    var threadsPerThreadgroup = min(maxThreadsPerThreadgroup, 256)
    threadsPerThreadgroup = (threadsPerThreadgroup / threadExecutionWidth) * threadExecutionWidth
    
    let threadgroupsPerGrid = (dataSize + threadsPerThreadgroup - 1) / threadsPerThreadgroup
    
    return (
        MTLSize(width: threadsPerThreadgroup, height: 1, depth: 1),
        MTLSize(width: threadgroupsPerGrid, height: 1, depth: 1)
    )
}
```

#### 减少 CPU-GPU 同步
```swift
// 避免频繁的 waitUntilCompleted()
class AsyncComputeManager {
    private var pendingOperations: [MTLCommandBuffer] = []
    
    func submitAsync(operation: (MTLCommandBuffer) -> Void) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        operation(commandBuffer)
        commandBuffer.commit()
        
        pendingOperations.append(commandBuffer)
        
        // 清理已完成的操作
        pendingOperations.removeAll { $0.status == .completed }
    }
    
    func waitForAll() {
        for buffer in pendingOperations {
            buffer.waitUntilCompleted()
        }
        pendingOperations.removeAll()
    }
}
```

### 3. 数值精度问题

**症状**：
```
计算结果不正确
有限域运算溢出
椭圆曲线点验证失败
```

**诊断**：
```metal
// 添加调试输出
kernel void debug_field_operations(
    device const FieldElement* input [[buffer(0)]],
    device FieldElement* output [[buffer(1)]],
    device uint* debug_info [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    FieldElement a = input[gid * 2];
    FieldElement b = input[gid * 2 + 1];
    
    // 检查输入是否有效
    if (!is_valid_field_element(a) || !is_valid_field_element(b)) {
        debug_info[gid] = 0xDEADBEEF;  // 错误标记
        return;
    }
    
    FieldElement result = field_add(a, b);
    
    // 验证结果
    if (!is_valid_field_element(result)) {
        debug_info[gid] = 0xBADC0DE;  // 结果无效
    } else {
        debug_info[gid] = 0x600D;  // 正常
    }
    
    output[gid] = result;
}
```

**解决方案**：

#### 实现正确的模运算
```metal
// 确保模运算的正确实现
FieldElement field_add(FieldElement a, FieldElement b) {
    FieldElement result;
    uint64_t carry = 0;
    
    // 加法
    for (int i = 0; i < 4; i++) {
        uint64_t sum = a.limbs[i] + b.limbs[i] + carry;
        result.limbs[i] = sum;
        carry = (sum < a.limbs[i]) ? 1 : 0;
    }
    
    // 条件减法（避免分支）
    FieldElement temp = field_sub_no_underflow(result, FIELD_MODULUS);
    bool should_reduce = (carry > 0) || field_gte(result, FIELD_MODULUS);
    
    return should_reduce ? temp : result;
}
```

#### 添加断言和验证
```metal
bool is_valid_field_element(FieldElement a) {
    return field_lt(a, FIELD_MODULUS);
}

bool field_lt(FieldElement a, constant uint64_t* modulus) {
    for (int i = 3; i >= 0; i--) {
        if (a.limbs[i] < modulus[i]) return true;
        if (a.limbs[i] > modulus[i]) return false;
    }
    return false;  // 相等情况
}
```

## 调试技巧

### 1. Metal 调试器使用

```swift
// 启用 Metal 验证层
#if DEBUG
let device = MTLCreateSystemDefaultDevice()!
// 在 Xcode 中设置环境变量：
// MTL_DEBUG_LAYER = 1
// MTL_SHADER_VALIDATION = 1
#endif
```

### 2. 日志和断点

```swift
class DebugLogger {
    static func logBufferContents<T>(_ buffer: MTLBuffer, type: T.Type, count: Int) {
        let pointer = buffer.contents().bindMemory(to: T.self, capacity: count)
        
        print("Buffer contents (\(count) elements):")
        for i in 0..<min(count, 10) {  // 只打印前 10 个元素
            print("  [\(i)]: \(pointer[i])")
        }
        
        if count > 10 {
            print("  ... (\(count - 10) more elements)")
        }
    }
    
    static func validateComputeState(_ computeEncoder: MTLComputeCommandEncoder,
                                   pipelineState: MTLComputePipelineState) {
        print("Pipeline state: \(pipelineState.label ?? "unnamed")")
        print("Max threads per threadgroup: \(pipelineState.maxTotalThreadsPerThreadgroup)")
        print("Thread execution width: \(pipelineState.threadExecutionWidth)")
    }
}
```

### 3. 单元测试

```swift
class MetalComputeTests: XCTestCase {
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    
    override func setUp() {
        super.setUp()
        device = MTLCreateSystemDefaultDevice()
        commandQueue = device.makeCommandQueue()
        
        XCTAssertNotNil(device, "Metal 设备应该可用")
        XCTAssertNotNil(commandQueue, "命令队列应该创建成功")
    }
    
    func testFieldAddition() {
        // 测试有限域加法的正确性
        let testCases: [(FieldElement, FieldElement, FieldElement)] = [
            // (a, b, expected_result)
            (FieldElement(limbs: (1, 0, 0, 0)), 
             FieldElement(limbs: (2, 0, 0, 0)), 
             FieldElement(limbs: (3, 0, 0, 0))),
            // 更多测试案例...
        ]
        
        for (a, b, expected) in testCases {
            let result = performFieldAddition(a: a, b: b)
            XCTAssertEqual(result, expected, "有限域加法结果不正确")
        }
    }
    
    private func performFieldAddition(a: FieldElement, b: FieldElement) -> FieldElement {
        // 实现 GPU 计算并返回结果
        // ...
        return FieldElement(limbs: (0, 0, 0, 0))  // 占位符
    }
}
```

## 常见错误代码

### Metal 错误代码对照表

| 错误代码 | 含义 | 解决方案 |
|---------|------|----------|
| IOAF code 1 | 无效参数 | 检查缓冲区大小和对齐 |
| IOAF code 2 | 内存不足 | 减少内存使用或分批处理 |
| IOAF code 3 | 设备丢失 | 重新创建 Metal 设备 |
| IOAF code 5 | 资源短缺 | 释放未使用的资源 |

### 性能警告

| 警告 | 原因 | 解决方案 |
|------|------|----------|
| 低 GPU 利用率 | 线程配置不当 | 调整线程组大小 |
| 高内存带宽 | 内存访问模式差 | 优化数据布局 |
| 频繁同步 | CPU-GPU 同步过多 | 使用异步计算 |

## 获取帮助

### 1. 系统信息收集

```bash
#!/bin/bash
# 收集系统信息脚本

echo "=== 系统信息 ==="
sw_vers
echo ""

echo "=== 硬件信息 ==="
system_profiler SPHardwareDataType | grep -E "(Model Name|Chip|Memory)"
echo ""

echo "=== GPU 信息 ==="
system_profiler SPDisplaysDataType | grep -E "(Chipset Model|VRAM|Metal)"
echo ""

echo "=== Xcode 信息 ==="
xcode-select -p
xcrun --show-sdk-version
echo ""

echo "=== Python 环境 ==="
python3 --version
pip3 list | grep -i objc
```

### 2. 日志收集

```swift
class LogCollector {
    static func collectLogs() -> String {
        var logs = "=== Metal GPU ZKP 调试日志 ===\n"
        
        // 设备信息
        if let device = MTLCreateSystemDefaultDevice() {
            logs += "设备名称: \(device.name)\n"
            logs += "最大线程组大小: \(device.maxThreadsPerThreadgroup)\n"
            logs += "推荐工作集大小: \(device.recommendedMaxWorkingSetSize / 1024 / 1024) MB\n"
            logs += "当前分配大小: \(device.currentAllocatedSize / 1024 / 1024) MB\n"
        }
        
        // 系统信息
        logs += "系统版本: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        
        return logs
    }
}
```

### 3. 社区资源

- **Apple Developer Forums**: [Metal 相关讨论](https://developer.apple.com/forums/tags/metal)
- **Stack Overflow**: 搜索 "Metal macOS" 相关问题
- **GitHub Issues**: 查看相关开源项目的问题跟踪
- **Apple 技术支持**: 对于严重的系统级问题

记住：在寻求帮助时，请提供完整的错误信息、系统配置和重现步骤。