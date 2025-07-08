# FFT/NTT GPU 实现

## 概述

快速傅里叶变换 (FFT) 和数论变换 (NTT) 是 ZKP 中最重要的计算密集型操作之一。本目录包含针对 Mac GPU 优化的实现。

## 算法背景

### FFT vs NTT

| 特性 | FFT | NTT |
|------|-----|-----|
| 数域 | 复数域 | 有限域 |
| 精度 | 浮点精度限制 | 精确计算 |
| ZKP 应用 | 预处理阶段 | 核心多项式运算 |
| GPU 适配性 | 很好 | 优秀 |

### 复杂度分析

- **时间复杂度**: O(n log n)
- **空间复杂度**: O(n)
- **并行度**: O(n) 理论上完全并行

## Metal 实现

### 1. NTT 核心着色器

```metal
#include <metal_stdlib>
using namespace metal;

// NTT 基本参数
constant uint MODULUS = 0x73eda753299d7d48;  // BLS12-381 标量域
constant uint ROOT_OF_UNITY = 0x1234567890abcdef;  // 原根

kernel void ntt_butterfly_step(
    device uint64_t* data [[buffer(0)]],
    constant uint& step_size [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint n = step_size * 2;
    uint group_id = id / step_size;
    uint local_id = id % step_size;
    
    uint i = group_id * n + local_id;
    uint j = i + step_size;
    
    // 计算旋转因子
    uint64_t omega = pow_mod(ROOT_OF_UNITY, local_id * (1 << (stage)), MODULUS);
    
    // 蝶形运算
    uint64_t u = data[i];
    uint64_t v = mul_mod(data[j], omega, MODULUS);
    
    data[i] = add_mod(u, v, MODULUS);
    data[j] = sub_mod(u, v, MODULUS);
}

// 模运算辅助函数
uint64_t add_mod(uint64_t a, uint64_t b, uint64_t mod) {
    uint64_t sum = a + b;
    return sum >= mod ? sum - mod : sum;
}

uint64_t sub_mod(uint64_t a, uint64_t b, uint64_t mod) {
    return a >= b ? a - b : a + mod - b;
}

uint64_t mul_mod(uint64_t a, uint64_t b, uint64_t mod) {
    // 使用 Montgomery 乘法或其他高效实现
    return (a * b) % mod;  // 简化版本
}

uint64_t pow_mod(uint64_t base, uint64_t exp, uint64_t mod) {
    uint64_t result = 1;
    while (exp > 0) {
        if (exp & 1) {
            result = mul_mod(result, base, mod);
        }
        base = mul_mod(base, base, mod);
        exp >>= 1;
    }
    return result;
}
```

### 2. Swift 包装器

```swift
import Metal
import Foundation

public class MetalNTT {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let computePipelineState: MTLComputePipelineState
    
    public init?() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        
        // 编译 Metal 着色器
        guard let library = device.makeDefaultLibrary(),
              let function = library.makeFunction(name: "ntt_butterfly_step"),
              let pipelineState = try? device.makeComputePipelineState(function: function) else {
            return nil
        }
        
        self.computePipelineState = pipelineState
    }
    
    public func ntt(_ input: [UInt64]) -> [UInt64]? {
        let count = input.count
        guard count.nonzeroBitCount == 1 else {
            print("输入大小必须是 2 的幂")
            return nil
        }
        
        // 创建缓冲区
        guard let buffer = device.makeBuffer(
            bytes: input,
            length: count * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        // 执行 NTT
        let stages = Int(log2(Double(count)))
        
        for stage in 0..<stages {
            let stepSize = 1 << stage
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            
            encoder.setComputePipelineState(computePipelineState)
            encoder.setBuffer(buffer, offset: 0, index: 0)
            
            var stepSizeVar = UInt32(stepSize)
            var stageVar = UInt32(stage)
            encoder.setBytes(&stepSizeVar, length: MemoryLayout<UInt32>.size, index: 1)
            encoder.setBytes(&stageVar, length: MemoryLayout<UInt32>.size, index: 2)
            
            let threadsPerGroup = MTLSize(width: min(1024, stepSize), height: 1, depth: 1)
            let groupsPerGrid = MTLSize(
                width: (stepSize + threadsPerGroup.width - 1) / threadsPerGroup.width,
                height: 1,
                depth: 1
            )
            
            encoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
        }
        
        // 读取结果
        let resultPointer = buffer.contents().bindMemory(to: UInt64.self, capacity: count)
        return Array(UnsafeBufferPointer(start: resultPointer, count: count))
    }
    
    public func intt(_ input: [UInt64]) -> [UInt64]? {
        // 逆 NTT 实现
        guard var result = ntt(input.reversed()) else { return nil }
        
        // 除以 n 并取模
        let n = UInt64(input.count)
        let nInverse = modInverse(n, modulus: 0x73eda753299d7d48)
        
        for i in 0..<result.count {
            result[i] = (result[i] * nInverse) % 0x73eda753299d7d48
        }
        
        return result
    }
    
    private func modInverse(_ a: UInt64, modulus: UInt64) -> UInt64 {
        // 扩展欧几里得算法实现
        var (old_r, r) = (Int64(a), Int64(modulus))
        var (old_s, s) = (Int64(1), Int64(0))
        
        while r != 0 {
            let quotient = old_r / r
            (old_r, r) = (r, old_r - quotient * r)
            (old_s, s) = (s, old_s - quotient * s)
        }
        
        return UInt64((old_s % Int64(modulus) + Int64(modulus)) % Int64(modulus))
    }
}
```

## 性能优化

### 1. 内存访问模式

```swift
// 使用 coalesced 内存访问
// 确保相邻线程访问相邻内存位置

// 优化前：随机访问
for i in 0..<n {
    let j = bitReverse(i, logN)
    // 访问 data[j]
}

// 优化后：顺序访问 + 位反转预处理
let bitReversedIndices = precomputeBitReverse(n)
// 批量重排数据
```

### 2. 共享内存利用

```metal
// 使用 threadgroup 内存减少全局内存访问
kernel void optimized_ntt_step(
    device uint64_t* data [[buffer(0)]],
    threadgroup uint64_t* shared_data [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint gid [[thread_position_in_grid]]
) {
    // 加载数据到共享内存
    shared_data[tid] = data[gid];
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 在共享内存中执行计算
    // ...
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 写回全局内存
    data[gid] = shared_data[tid];
}
```

## 基准测试

### 测试代码

```swift
import Foundation

class NTTBenchmark {
    let metalNTT: MetalNTT
    
    init?() {
        guard let ntt = MetalNTT() else { return nil }
        self.metalNTT = ntt
    }
    
    func benchmark() {
        let sizes = [1024, 4096, 16384, 65536, 262144, 1048576]
        
        print("NTT 性能基准测试")
        print("大小\t\tCPU时间\t\tGPU时间\t\t加速比")
        print("-" * 50)
        
        for size in sizes {
            let input = generateRandomInput(size: size)
            
            // CPU 基准
            let cpuStart = CFAbsoluteTimeGetCurrent()
            let cpuResult = cpuNTT(input)
            let cpuTime = CFAbsoluteTimeGetCurrent() - cpuStart
            
            // GPU 基准
            let gpuStart = CFAbsoluteTimeGetCurrent()
            let gpuResult = metalNTT.ntt(input)
            let gpuTime = CFAbsoluteTimeGetCurrent() - gpuStart
            
            let speedup = cpuTime / gpuTime
            
            print("\(size)\t\t\(String(format: "%.2f", cpuTime * 1000))ms\t\t\(String(format: "%.2f", gpuTime * 1000))ms\t\t\(String(format: "%.2f", speedup))x")
            
            // 验证结果正确性
            assert(cpuResult == gpuResult, "结果不匹配")
        }
    }
    
    private func generateRandomInput(size: Int) -> [UInt64] {
        return (0..<size).map { _ in UInt64.random(in: 0..<0x73eda753299d7d48) }
    }
    
    private func cpuNTT(_ input: [UInt64]) -> [UInt64] {
        // CPU 参考实现
        // 这里应该实现标准的 NTT 算法
        return input  // 简化
    }
}

// 运行基准测试
if let benchmark = NTTBenchmark() {
    benchmark.benchmark()
}
```

## 使用示例

```swift
// 基本使用
let ntt = MetalNTT()!
let input: [UInt64] = [1, 2, 3, 4, 0, 0, 0, 0]  // 8 个元素
let transformed = ntt.ntt(input)!
let recovered = ntt.intt(transformed)!

print("原始: \(input)")
print("变换: \(transformed)")
print("恢复: \(recovered)")

// 多项式乘法示例
func polynomialMultiply(_ a: [UInt64], _ b: [UInt64]) -> [UInt64] {
    let size = 1 << Int(ceil(log2(Double(a.count + b.count - 1))))
    
    var paddedA = a + Array(repeating: 0, count: size - a.count)
    var paddedB = b + Array(repeating: 0, count: size - b.count)
    
    let nttA = ntt.ntt(paddedA)!
    let nttB = ntt.ntt(paddedB)!
    
    let pointwise = zip(nttA, nttB).map { ($0 * $1) % 0x73eda753299d7d48 }
    
    return ntt.intt(pointwise)!
}
```

## 下一步

1. 查看 [多标量乘法优化](../msm/)
2. 探索 [椭圆曲线 GPU 运算](../elliptic-curves/)
3. 学习 [Metal 编程最佳实践](../../docs/metal-programming.md)