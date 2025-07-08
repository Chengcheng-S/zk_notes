# GPU 优化技巧 - Mac ZKP 计算

## 概述

本文档提供在 Mac 平台上优化 ZKP GPU 计算的实用技巧和最佳实践。

## 硬件特定优化

### Apple Silicon (M1/M2/M3) 优化

#### 统一内存架构利用
```swift
// 利用统一内存架构，减少数据拷贝
class UnifiedMemoryManager {
    let device: MTLDevice
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func createSharedBuffer<T>(for data: [T]) -> MTLBuffer? {
        let size = data.count * MemoryLayout<T>.stride
        
        // 使用 shared 模式，CPU 和 GPU 共享内存
        guard let buffer = device.makeBuffer(
            bytes: data,
            length: size,
            options: .storageModeShared
        ) else { return nil }
        
        return buffer
    }
    
    func createManagedBuffer(size: Int) -> MTLBuffer? {
        // 对于大数据，使用 managed 模式
        return device.makeBuffer(
            length: size,
            options: .storageModeManaged
        )
    }
}
```

#### GPU 集群利用
```metal
// 针对 M2/M3 的多 GPU 集群优化
kernel void clustered_ntt(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& cluster_id [[buffer(2)]],
    constant uint& total_clusters [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    // 根据集群 ID 分配工作
    uint elements_per_cluster = get_total_elements() / total_clusters;
    uint start_idx = cluster_id * elements_per_cluster;
    uint end_idx = min(start_idx + elements_per_cluster, get_total_elements());
    
    if (gid >= (end_idx - start_idx)) return;
    
    uint actual_idx = start_idx + gid;
    // 执行 NTT 计算...
}
```

### Intel Mac 优化

#### 离散 GPU 内存管理
```swift
class DiscreteGPUManager {
    let device: MTLDevice
    private var memoryPool: [MTLBuffer] = []
    
    init(device: MTLDevice) {
        self.device = device
    }
    
    func optimizeForDiscreteGPU() {
        // 预分配大块内存，减少分配开销
        let poolSize = 256 * 1024 * 1024  // 256MB
        
        for _ in 0..<4 {
            if let buffer = device.makeBuffer(
                length: poolSize,
                options: .storageModePrivate
            ) {
                memoryPool.append(buffer)
            }
        }
    }
    
    func getBuffer(size: Int) -> MTLBuffer? {
        // 从内存池中分配
        for buffer in memoryPool {
            if buffer.length >= size {
                return buffer
            }
        }
        
        // 如果池中没有合适的，创建新的
        return device.makeBuffer(
            length: size,
            options: .storageModePrivate
        )
    }
}
```

## 算法级优化

### 1. NTT 优化策略

#### 分层 NTT
```metal
// 分层 NTT 实现，优化缓存利用
kernel void hierarchical_ntt(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& layer [[buffer(2)]],
    uint gid [[thread_position_in_grid]],
    uint lid [[thread_position_in_threadgroup]]
) {
    threadgroup FieldElement cache[512];
    
    uint elements_per_layer = 512;
    uint layer_start = layer * elements_per_layer;
    
    // 第一层：加载到缓存
    if (lid < elements_per_layer && (layer_start + lid) < get_total_elements()) {
        cache[lid] = data[layer_start + lid];
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 第二层：在缓存中执行小规模 NTT
    for (uint stage = 0; stage < 9; stage++) {  // log2(512) = 9
        uint stride = 1 << stage;
        uint pairs_per_thread = elements_per_layer / (2 * get_threadgroup_size());
        
        for (uint i = 0; i < pairs_per_thread; i++) {
            uint pair_idx = lid * pairs_per_thread + i;
            uint base = (pair_idx / stride) * (stride * 2) + (pair_idx % stride);
            
            if (base + stride < elements_per_layer) {
                FieldElement u = cache[base];
                FieldElement v = field_mul(cache[base + stride], 
                                         twiddle_factors[pair_idx]);
                
                cache[base] = field_add(u, v);
                cache[base + stride] = field_sub(u, v);
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // 第三层：写回全局内存
    if (lid < elements_per_layer && (layer_start + lid) < get_total_elements()) {
        data[layer_start + lid] = cache[lid];
    }
}
```

#### 混合基数 NTT
```metal
// 混合基数 NTT，减少旋转因子访问
kernel void mixed_radix_ntt(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors_2 [[buffer(1)]],
    device const FieldElement* twiddle_factors_4 [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    // 基数-4 蝶形运算
    uint group_size = 4;
    uint group_id = gid / group_size;
    uint local_id = gid % group_size;
    
    uint base_idx = group_id * group_size;
    
    // 加载 4 个元素
    FieldElement x[4];
    for (uint i = 0; i < 4; i++) {
        x[i] = data[base_idx + i];
    }
    
    // 基数-4 DIT 蝶形
    FieldElement t0 = field_add(x[0], x[2]);
    FieldElement t1 = field_sub(x[0], x[2]);
    FieldElement t2 = field_add(x[1], x[3]);
    FieldElement t3 = field_sub(x[1], x[3]);
    
    // 应用旋转因子
    t3 = field_mul(t3, twiddle_factors_4[group_id]);
    
    x[0] = field_add(t0, t2);
    x[1] = field_add(t1, t3);
    x[2] = field_sub(t0, t2);
    x[3] = field_sub(t1, t3);
    
    // 写回结果
    data[base_idx + local_id] = x[local_id];
}
```

### 2. MSM 优化策略

#### 自适应窗口大小
```swift
class AdaptiveMSM {
    static func optimalWindowSize(for scalarCount: Int, device: MTLDevice) -> Int {
        let memoryBudget = device.recommendedMaxWorkingSetSize
        let pointSize = MemoryLayout<G1Point>.size
        
        // 根据内存预算和标量数量选择窗口大小
        for windowSize in stride(from: 16, to: 4, by: -1) {
            let bucketCount = 1 << windowSize
            let memoryRequired = bucketCount * pointSize
            
            if memoryRequired <= memoryBudget / 4 {  // 保留 75% 内存给其他用途
                return windowSize
            }
        }
        
        return 8  // 最小窗口大小
    }
    
    func computeMSM(scalars: [FieldElement], 
                   points: [G1Point],
                   device: MTLDevice) -> G1Point {
        let windowSize = Self.optimalWindowSize(for: scalars.count, device: device)
        
        // 使用计算出的最优窗口大小执行 MSM
        return performBucketMSM(scalars: scalars, 
                               points: points, 
                               windowSize: windowSize,
                               device: device)
    }
}
```

#### 流水线 MSM
```metal
// 流水线 MSM 实现，隐藏内存延迟
kernel void pipelined_msm_bucket(
    device const uint256* scalars [[buffer(0)]],
    device const G1Point* points [[buffer(1)]],
    device G1Point* buckets [[buffer(2)]],
    constant uint& window_start [[buffer(3)]],
    constant uint& window_size [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    // 预取下一批数据
    uint prefetch_offset = 64;  // 预取 64 个元素
    
    if (gid + prefetch_offset < get_total_scalars()) {
        // 触发预取（编译器优化）
        volatile uint256 prefetch_scalar = scalars[gid + prefetch_offset];
        volatile G1Point prefetch_point = points[gid + prefetch_offset];
    }
    
    // 处理当前元素
    if (gid < get_total_scalars()) {
        uint256 scalar = scalars[gid];
        G1Point point = points[gid];
        
        // 提取窗口位
        uint bucket_idx = extract_window_bits(scalar, window_start, window_size);
        
        if (bucket_idx > 0) {
            // 原子加法到桶中
            atomic_point_add(&buckets[bucket_idx], point);
        }
    }
}
```

## 内存优化

### 1. 内存池管理

```swift
class MemoryPool {
    private let device: MTLDevice
    private var freeBuffers: [Int: [MTLBuffer]] = [:]
    private var usedBuffers: Set<MTLBuffer> = []
    private let lock = NSLock()
    
    init(device: MTLDevice) {
        self.device = device
        preallocateBuffers()
    }
    
    private func preallocateBuffers() {
        let commonSizes = [
            1024 * 1024,      // 1MB
            4 * 1024 * 1024,  // 4MB
            16 * 1024 * 1024, // 16MB
            64 * 1024 * 1024  // 64MB
        ]
        
        for size in commonSizes {
            freeBuffers[size] = []
            for _ in 0..<4 {
                if let buffer = device.makeBuffer(
                    length: size,
                    options: .storageModePrivate
                ) {
                    freeBuffers[size]?.append(buffer)
                }
            }
        }
    }
    
    func getBuffer(size: Int) -> MTLBuffer? {
        lock.lock()
        defer { lock.unlock() }
        
        // 找到最小的合适大小
        let suitableSize = freeBuffers.keys
            .filter { $0 >= size }
            .min()
        
        guard let targetSize = suitableSize,
              let buffer = freeBuffers[targetSize]?.popLast() else {
            // 如果池中没有，创建新的
            return device.makeBuffer(
                length: size,
                options: .storageModePrivate
            )
        }
        
        usedBuffers.insert(buffer)
        return buffer
    }
    
    func returnBuffer(_ buffer: MTLBuffer) {
        lock.lock()
        defer { lock.unlock() }
        
        usedBuffers.remove(buffer)
        
        let size = buffer.length
        if freeBuffers[size] == nil {
            freeBuffers[size] = []
        }
        
        freeBuffers[size]?.append(buffer)
    }
}
```

### 2. 数据布局优化

```metal
// 结构体数组 vs 数组结构体
// 好的做法：数组结构体（AoS to SoA）
struct OptimizedFieldElements {
    device uint64_t* limb0;
    device uint64_t* limb1;
    device uint64_t* limb2;
    device uint64_t* limb3;
};

kernel void optimized_field_add(
    OptimizedFieldElements a [[buffer(0)]],
    OptimizedFieldElements b [[buffer(1)]],
    OptimizedFieldElements result [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    // 向量化加载和存储
    uint4 a_limbs = uint4(a.limb0[gid], a.limb1[gid], a.limb2[gid], a.limb3[gid]);
    uint4 b_limbs = uint4(b.limb0[gid], b.limb1[gid], b.limb2[gid], b.limb3[gid]);
    
    // 向量化运算
    uint4 sum = a_limbs + b_limbs;
    
    // 向量化存储
    result.limb0[gid] = sum.x;
    result.limb1[gid] = sum.y;
    result.limb2[gid] = sum.z;
    result.limb3[gid] = sum.w;
}
```

## 并发优化

### 1. 多命令队列

```swift
class MultiQueueManager {
    private let device: MTLDevice
    private let computeQueue: MTLCommandQueue
    private let copyQueue: MTLCommandQueue
    private let blitQueue: MTLCommandQueue
    
    init(device: MTLDevice) {
        self.device = device
        self.computeQueue = device.makeCommandQueue()!
        self.copyQueue = device.makeCommandQueue()!
        self.blitQueue = device.makeCommandQueue()!
        
        computeQueue.label = "Compute Queue"
        copyQueue.label = "Copy Queue"
        blitQueue.label = "Blit Queue"
    }
    
    func executeOverlapped(
        computeWork: @escaping (MTLCommandBuffer) -> Void,
        copyWork: @escaping (MTLCommandBuffer) -> Void
    ) {
        let computeBuffer = computeQueue.makeCommandBuffer()!
        let copyBuffer = copyQueue.makeCommandBuffer()!
        
        // 并行执行计算和数据传输
        DispatchQueue.global().async {
            computeWork(computeBuffer)
            computeBuffer.commit()
        }
        
        DispatchQueue.global().async {
            copyWork(copyBuffer)
            copyBuffer.commit()
        }
        
        // 等待两个队列完成
        computeBuffer.waitUntilCompleted()
        copyBuffer.waitUntilCompleted()
    }
}
```

### 2. 异步计算流水线

```swift
class ComputePipeline {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pendingBuffers: [MTLCommandBuffer] = []
    
    init(device: MTLDevice) {
        self.device = device
        self.commandQueue = device.makeCommandQueue()!
    }
    
    func submitAsync<T>(
        operation: @escaping (MTLCommandBuffer) -> Void,
        completion: @escaping (T) -> Void
    ) {
        let commandBuffer = commandQueue.makeCommandBuffer()!
        
        commandBuffer.addCompletedHandler { buffer in
            DispatchQueue.main.async {
                // 处理结果
                completion(/* 结果 */)
            }
        }
        
        operation(commandBuffer)
        commandBuffer.commit()
        
        pendingBuffers.append(commandBuffer)
        
        // 清理已完成的缓冲区
        pendingBuffers.removeAll { $0.status == .completed }
    }
    
    func waitForAll() {
        for buffer in pendingBuffers {
            buffer.waitUntilCompleted()
        }
        pendingBuffers.removeAll()
    }
}
```

## 性能监控和调试

### 1. 实时性能监控

```swift
class PerformanceMonitor {
    private var metrics: [String: [Double]] = [:]
    private let lock = NSLock()
    
    func recordMetric(name: String, value: Double) {
        lock.lock()
        defer { lock.unlock() }
        
        if metrics[name] == nil {
            metrics[name] = []
        }
        metrics[name]?.append(value)
        
        // 保持最近 100 个样本
        if metrics[name]!.count > 100 {
            metrics[name]?.removeFirst()
        }
    }
    
    func getAverageMetric(name: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let values = metrics[name], !values.isEmpty else {
            return nil
        }
        
        return values.reduce(0, +) / Double(values.count)
    }
    
    func printSummary() {
        lock.lock()
        defer { lock.unlock() }
        
        print("=== 性能监控摘要 ===")
        for (name, values) in metrics {
            let avg = values.reduce(0, +) / Double(values.count)
            let min = values.min() ?? 0
            let max = values.max() ?? 0
            
            print("\(name):")
            print("  平均: \(String(format: "%.2f", avg)) ms")
            print("  最小: \(String(format: "%.2f", min)) ms")
            print("  最大: \(String(format: "%.2f", max)) ms")
        }
    }
}
```

### 2. GPU 利用率监控

```swift
extension MTLDevice {
    func getUtilization() -> (gpu: Double, memory: Double) {
        // 注意：这是伪代码，实际实现需要使用私有 API 或系统工具
        let gpuUtilization = getCurrentGPUUtilization()
        let memoryUtilization = Double(currentAllocatedSize) / Double(recommendedMaxWorkingSetSize)
        
        return (gpu: gpuUtilization, memory: memoryUtilization)
    }
    
    private func getCurrentGPUUtilization() -> Double {
        // 实际实现可能需要使用 IOKit 或其他系统 API
        // 这里返回模拟值
        return 0.75  // 75% 利用率
    }
}
```

## 平台特定调优

### Apple Silicon 特定优化

```swift
class AppleSiliconOptimizer {
    static func detectChipType() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        
        let modelString = String(cString: model)
        
        if modelString.contains("Mac14") {
            return "M2"
        } else if modelString.contains("Mac13") {
            return "M1"
        } else if modelString.contains("Mac15") {
            return "M3"
        }
        
        return "Unknown"
    }
    
    static func optimizeForChip(_ chipType: String, device: MTLDevice) {
        switch chipType {
        case "M1":
            // M1 特定优化
            configureForM1(device)
        case "M2":
            // M2 特定优化
            configureForM2(device)
        case "M3":
            // M3 特定优化
            configureForM3(device)
        default:
            // 通用优化
            configureGeneric(device)
        }
    }
    
    private static func configureForM1(_ device: MTLDevice) {
        // M1 有 8 个 GPU 核心
        // 优化线程组大小和内存访问模式
    }
    
    private static func configureForM2(_ device: MTLDevice) {
        // M2 有 10 个 GPU 核心
        // 可以使用更大的线程组
    }
    
    private static func configureForM3(_ device: MTLDevice) {
        // M3 有更多的 GPU 核心和改进的架构
        // 可以使用最激进的优化策略
    }
}
```

## 总结

这些优化技巧涵盖了从硬件层面到算法层面的各个方面：

1. **硬件优化**：充分利用 Apple Silicon 的统一内存架构
2. **算法优化**：使用分层、混合基数等高级算法技巧
3. **内存优化**：实现高效的内存池和数据布局
4. **并发优化**：利用多队列和异步计算提高吞吐量
5. **监控调试**：建立完善的性能监控体系

通过应用这些技巧，可以显著提高 ZKP 计算在 Mac 平台上的性能。