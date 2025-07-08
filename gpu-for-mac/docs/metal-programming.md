# Metal 编程指南 - ZKP 计算优化

## 概述

本指南专门针对零知识证明计算中的 Metal 编程，涵盖从基础概念到高级优化技巧。

## Metal 基础概念

### 1. Metal 架构概览

```
CPU (Host) ←→ GPU (Device)
    ↓           ↓
应用程序 ←→ Metal 着色器
    ↓           ↓
Swift/ObjC ←→ Metal Shading Language
```

### 2. 核心组件

#### MTLDevice
```swift
// 获取默认 GPU 设备
guard let device = MTLCreateSystemDefaultDevice() else {
    fatalError("Metal 不支持")
}

// 检查设备能力
print("设备名称: \(device.name)")
print("最大线程组大小: \(device.maxThreadsPerThreadgroup)")
print("推荐工作组大小: \(device.recommendedMaxWorkingSetSize)")
```

#### MTLCommandQueue
```swift
// 创建命令队列
let commandQueue = device.makeCommandQueue()!

// 命令队列是线程安全的，可以在多线程中使用
```

#### MTLBuffer
```swift
// 创建缓冲区
let bufferSize = MemoryLayout<Float>.size * 1024
let buffer = device.makeBuffer(length: bufferSize, 
                              options: .storageModeShared)!

// 访问缓冲区数据
let pointer = buffer.contents().bindMemory(to: Float.self, 
                                          capacity: 1024)
```

## ZKP 特定的 Metal 编程

### 1. 有限域运算

#### 基本有限域结构
```metal
#include <metal_stdlib>
using namespace metal;

// BLS12-381 标量域素数
constant uint64_t BLS12_381_SCALAR_MODULUS[4] = {
    0x73eda753299d7d48,
    0x06d89f71cab8351f,
    0x2833e84879b97091,
    0x30644e72e131a029
};

struct FieldElement {
    uint64_t limbs[4];  // 256位整数，4个64位limb
};

// 模加法
FieldElement field_add(FieldElement a, FieldElement b) {
    FieldElement result;
    uint64_t carry = 0;
    
    for (int i = 0; i < 4; i++) {
        uint64_t sum = a.limbs[i] + b.limbs[i] + carry;
        result.limbs[i] = sum;
        carry = (sum < a.limbs[i]) ? 1 : 0;
    }
    
    // 如果结果 >= 模数，则减去模数
    if (field_gte(result, BLS12_381_SCALAR_MODULUS)) {
        result = field_sub(result, BLS12_381_SCALAR_MODULUS);
    }
    
    return result;
}
```

#### 蒙哥马利乘法
```metal
// 蒙哥马利乘法实现
FieldElement montgomery_mul(FieldElement a, FieldElement b) {
    uint64_t t[8] = {0};  // 临时结果
    
    // 第一阶段：计算 a * b
    for (int i = 0; i < 4; i++) {
        uint64_t carry = 0;
        for (int j = 0; j < 4; j++) {
            uint64_t prod = a.limbs[i] * b.limbs[j];
            uint64_t low = prod & 0xFFFFFFFFFFFFFFFF;
            uint64_t high = prod >> 64;
            
            uint64_t sum = t[i + j] + low + carry;
            t[i + j] = sum;
            carry = high + (sum < t[i + j] ? 1 : 0);
        }
        t[i + 4] = carry;
    }
    
    // 第二阶段：蒙哥马利约简
    // ... 实现约简算法
    
    FieldElement result;
    for (int i = 0; i < 4; i++) {
        result.limbs[i] = t[i + 4];
    }
    
    return result;
}
```

### 2. 椭圆曲线点运算

#### 点结构定义
```metal
struct G1Point {
    FieldElement x;
    FieldElement y;
    FieldElement z;  // 投影坐标
    bool is_infinity;
};

// 点加法（雅可比坐标）
G1Point point_add(G1Point p1, G1Point p2) {
    if (p1.is_infinity) return p2;
    if (p2.is_infinity) return p1;
    
    // 实现椭圆曲线点加法
    // 使用雅可比坐标避免除法运算
    
    FieldElement z1z1 = field_square(p1.z);
    FieldElement z2z2 = field_square(p2.z);
    FieldElement u1 = field_mul(p1.x, z2z2);
    FieldElement u2 = field_mul(p2.x, z1z1);
    
    // ... 完整的点加法实现
    
    G1Point result;
    // ... 设置结果
    return result;
}
```

### 3. NTT 实现

#### 基本 NTT 内核
```metal
kernel void ntt_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    constant uint& stage [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    uint stride = 1 << stage;
    uint m = n >> (stage + 1);
    
    if (gid >= m) return;
    
    uint base = (gid / stride) * (stride << 1) + (gid % stride);
    uint i = base;
    uint j = base + stride;
    
    FieldElement u = data[i];
    FieldElement v = field_mul(data[j], twiddle_factors[gid]);
    
    data[i] = field_add(u, v);
    data[j] = field_sub(u, v);
}
```

#### 优化的 NTT 实现
```metal
kernel void optimized_ntt_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& log_n [[buffer(2)]],
    uint gid [[thread_position_in_grid]],
    uint lid [[thread_position_in_threadgroup]],
    uint group_id [[threadgroup_position_in_grid]]
) {
    // 使用共享内存优化
    threadgroup FieldElement shared_data[256];
    
    uint n = 1 << log_n;
    uint elements_per_thread = n / get_num_threads();
    
    // 加载数据到共享内存
    for (uint i = 0; i < elements_per_thread; i++) {
        uint idx = gid * elements_per_thread + i;
        if (idx < n) {
            shared_data[lid * elements_per_thread + i] = data[idx];
        }
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 执行 NTT 计算
    for (uint stage = 0; stage < log_n; stage++) {
        uint m = 1 << (log_n - stage - 1);
        uint stride = 1 << stage;
        
        for (uint i = 0; i < elements_per_thread / 2; i++) {
            uint base_idx = lid * elements_per_thread + i * 2;
            uint twiddle_idx = (base_idx / (stride * 2)) * stride + (base_idx % stride);
            
            FieldElement u = shared_data[base_idx];
            FieldElement v = field_mul(shared_data[base_idx + stride], 
                                     twiddle_factors[twiddle_idx]);
            
            shared_data[base_idx] = field_add(u, v);
            shared_data[base_idx + stride] = field_sub(u, v);
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // 写回结果
    for (uint i = 0; i < elements_per_thread; i++) {
        uint idx = gid * elements_per_thread + i;
        if (idx < n) {
            data[idx] = shared_data[lid * elements_per_thread + i];
        }
    }
}
```

## 性能优化策略

### 1. 内存访问优化

#### 合并内存访问
```metal
// 好的做法：连续内存访问
kernel void good_memory_access(
    device float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    // 线程 i 访问元素 i，保证内存访问合并
    output[gid] = input[gid] * 2.0f;
}

// 坏的做法：跨步内存访问
kernel void bad_memory_access(
    device float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    // 线程 i 访问元素 i*stride，导致内存访问不连续
    uint stride = 128;
    output[gid] = input[gid * stride] * 2.0f;
}
```

#### 使用共享内存
```metal
kernel void shared_memory_example(
    device const float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]],
    uint lid [[thread_position_in_threadgroup]]
) {
    threadgroup float shared[256];
    
    // 加载到共享内存
    shared[lid] = input[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 在共享内存中进行计算
    float result = 0.0f;
    for (uint i = 0; i < 256; i++) {
        result += shared[i];
    }
    
    output[gid] = result;
}
```

### 2. 计算优化

#### 避免分支
```metal
// 好的做法：使用条件赋值
kernel void branchless_kernel(
    device const int* input [[buffer(0)]],
    device int* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    int value = input[gid];
    // 使用 select 避免分支
    output[gid] = select(value, -value, value < 0);
}

// 坏的做法：使用分支
kernel void branchy_kernel(
    device const int* input [[buffer(0)]],
    device int* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    int value = input[gid];
    if (value < 0) {
        output[gid] = -value;
    } else {
        output[gid] = value;
    }
}
```

#### 循环展开
```metal
// 手动循环展开提高性能
kernel void unrolled_loop(
    device const float* input [[buffer(0)]],
    device float* output [[buffer(1)]],
    uint gid [[thread_position_in_grid]]
) {
    float sum = 0.0f;
    uint base = gid * 8;
    
    // 展开循环
    sum += input[base + 0];
    sum += input[base + 1];
    sum += input[base + 2];
    sum += input[base + 3];
    sum += input[base + 4];
    sum += input[base + 5];
    sum += input[base + 6];
    sum += input[base + 7];
    
    output[gid] = sum;
}
```

### 3. 线程组织优化

#### 选择合适的线程组大小
```swift
// 根据计算类型选择线程组大小
func configureThreadgroups(for computeEncoder: MTLComputeCommandEncoder,
                          dataSize: Int,
                          computePipelineState: MTLComputePipelineState) {
    
    let threadsPerThreadgroup: MTLSize
    let threadgroupsPerGrid: MTLSize
    
    if dataSize < 1024 {
        // 小数据集：使用较小的线程组
        threadsPerThreadgroup = MTLSize(width: 64, height: 1, depth: 1)
    } else {
        // 大数据集：使用设备推荐的最大线程组大小
        let maxThreadsPerThreadgroup = computePipelineState.maxTotalThreadsPerThreadgroup
        threadsPerThreadgroup = MTLSize(width: min(maxThreadsPerThreadgroup, 256), 
                                       height: 1, depth: 1)
    }
    
    threadgroupsPerGrid = MTLSize(
        width: (dataSize + threadsPerThreadgroup.width - 1) / threadsPerThreadgroup.width,
        height: 1,
        depth: 1
    )
    
    computeEncoder.dispatchThreadgroups(threadgroupsPerGrid, 
                                       threadsPerThreadgroup: threadsPerThreadgroup)
}
```

## 调试和性能分析

### 1. Metal 调试工具

#### GPU 帧捕获
```swift
// 启用 Metal 调试
#if DEBUG
let device = MTLCreateSystemDefaultDevice()!
device.makeCommandQueue()?.label = "ZKP Command Queue"
#endif

// 在关键计算前后添加标记
commandBuffer.pushDebugGroup("NTT Computation")
// ... NTT 计算
commandBuffer.popDebugGroup()
```

#### 性能计数器
```swift
class MetalProfiler {
    private var startTime: CFTimeInterval = 0
    private var endTime: CFTimeInterval = 0
    
    func startProfiling() {
        startTime = CACurrentMediaTime()
    }
    
    func endProfiling() -> Double {
        endTime = CACurrentMediaTime()
        return (endTime - startTime) * 1000.0  // 转换为毫秒
    }
}

// 使用示例
let profiler = MetalProfiler()
profiler.startProfiling()

// 执行 Metal 计算
commandBuffer.commit()
commandBuffer.waitUntilCompleted()

let executionTime = profiler.endProfiling()
print("计算耗时: \(executionTime) ms")
```

### 2. 内存使用监控

```swift
func monitorMemoryUsage(device: MTLDevice) {
    let currentAllocatedSize = device.currentAllocatedSize
    let recommendedMaxWorkingSetSize = device.recommendedMaxWorkingSetSize
    
    print("当前分配内存: \(currentAllocatedSize / 1024 / 1024) MB")
    print("推荐最大工作集: \(recommendedMaxWorkingSetSize / 1024 / 1024) MB")
    
    if currentAllocatedSize > recommendedMaxWorkingSetSize {
        print("警告：内存使用超过推荐值")
    }
}
```

## 最佳实践总结

### 1. 设计原则
- **数据并行优先**：设计算法时优先考虑数据并行性
- **减少内存传输**：最小化 CPU-GPU 数据传输
- **批处理操作**：将多个小操作合并为大操作

### 2. 实现技巧
- **预分配缓冲区**：避免频繁的内存分配
- **异步执行**：使用命令缓冲区实现异步计算
- **错误处理**：完善的错误检查和恢复机制

### 3. 性能调优
- **基准测试**：建立完整的性能基准
- **渐进优化**：从正确性到性能的渐进优化
- **平台适配**：针对不同 Mac 型号进行优化

## 参考资源

- [Apple Metal 官方文档](https://developer.apple.com/metal/)
- [Metal Best Practices Guide](https://developer.apple.com/library/archive/documentation/Miscellaneous/Conceptual/MetalProgrammingGuide/)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)
- [WWDC Metal 相关视频](https://developer.apple.com/videos/graphics-and-games/)