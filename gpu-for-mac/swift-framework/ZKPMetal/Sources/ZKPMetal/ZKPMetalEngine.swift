import Metal
import Foundation

/// 主要的 ZKP Metal 计算引擎
public class ZKPMetalEngine {
    
    // MARK: - Properties
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary
    
    // 计算管道状态
    private let nttPipelineState: MTLComputePipelineState
    private let bitReversePipelineState: MTLComputePipelineState
    private let msmPipelineState: MTLComputePipelineState
    
    // 缓存的旋转因子
    private var twiddleFactorsCache: [Int: MTLBuffer] = [:]
    
    // MARK: - Initialization
    
    public init?() {
        // 获取 Metal 设备
        guard let device = MTLCreateSystemDefaultDevice() else {
            print("❌ Metal 设备不可用")
            return nil
        }
        
        self.device = device
        
        // 创建命令队列
        guard let commandQueue = device.makeCommandQueue() else {
            print("❌ 无法创建命令队列")
            return nil
        }
        
        self.commandQueue = commandQueue
        
        // 加载 Metal 库
        guard let library = device.makeDefaultLibrary() else {
            print("❌ 无法加载 Metal 库")
            return nil
        }
        
        self.library = library
        
        // 创建计算管道状态
        do {
            // NTT 管道
            guard let nttFunction = library.makeFunction(name: "ntt_butterfly_step") else {
                print("❌ 找不到 NTT 函数")
                return nil
            }
            self.nttPipelineState = try device.makeComputePipelineState(function: nttFunction)
            
            // 位反转管道
            guard let bitReverseFunction = library.makeFunction(name: "bit_reverse_permutation") else {
                print("❌ 找不到位反转函数")
                return nil
            }
            self.bitReversePipelineState = try device.makeComputePipelineState(function: bitReverseFunction)
            
            // MSM 管道
            guard let msmFunction = library.makeFunction(name: "msm_kernel") else {
                print("❌ 找不到 MSM 函数")
                return nil
            }
            self.msmPipelineState = try device.makeComputePipelineState(function: msmFunction)
            
        } catch {
            print("❌ 创建计算管道失败: \(error)")
            return nil
        }
        
        print("✅ ZKP Metal 引擎初始化成功")
        print("   设备: \(device.name)")
        print("   最大线程组大小: \(device.maxThreadsPerThreadgroup)")
    }
    
    // MARK: - Public API
    
    /// 执行数论变换 (NTT)
    /// - Parameter input: 输入数据，长度必须是 2 的幂
    /// - Returns: NTT 结果，如果失败返回 nil
    public func ntt(_ input: [UInt64]) -> [UInt64]? {
        guard input.count.nonzeroBitCount == 1 else {
            print("❌ 输入大小必须是 2 的幂")
            return nil
        }
        
        let logN = Int(log2(Double(input.count)))
        return performNTT(input, logN: logN, inverse: false)
    }
    
    /// 执行逆数论变换 (INTT)
    /// - Parameter input: 输入数据，长度必须是 2 的幂
    /// - Returns: INTT 结果，如果失败返回 nil
    public func intt(_ input: [UInt64]) -> [UInt64]? {
        guard input.count.nonzeroBitCount == 1 else {
            print("❌ 输入大小必须是 2 的幂")
            return nil
        }
        
        let logN = Int(log2(Double(input.count)))
        return performNTT(input, logN: logN, inverse: true)
    }
    
    /// 多项式乘法
    /// - Parameters:
    ///   - a: 第一个多项式
    ///   - b: 第二个多项式
    /// - Returns: 乘积多项式
    public func polynomialMultiply(_ a: [UInt64], _ b: [UInt64]) -> [UInt64]? {
        let resultSize = 1 << Int(ceil(log2(Double(a.count + b.count - 1))))
        
        // 填充到合适大小
        var paddedA = a + Array(repeating: 0, count: resultSize - a.count)
        var paddedB = b + Array(repeating: 0, count: resultSize - b.count)
        
        // 执行 NTT
        guard let nttA = ntt(paddedA),
              let nttB = ntt(paddedB) else {
            return nil
        }
        
        // 点乘
        let pointwise = zip(nttA, nttB).map { ($0 * $1) % FieldConstants.modulus }
        
        // 逆 NTT
        return intt(pointwise)
    }
    
    /// 多标量乘法 (MSM)
    /// - Parameters:
    ///   - scalars: 标量数组
    ///   - points: 椭圆曲线点数组
    /// - Returns: MSM 结果点
    public func msm(_ scalars: [UInt64], _ points: [EllipticCurvePoint]) -> EllipticCurvePoint? {
        guard scalars.count == points.count else {
            print("❌ 标量和点的数量必须相等")
            return nil
        }
        
        return performMSM(scalars, points)
    }
    
    // MARK: - Private Implementation
    
    private func performNTT(_ input: [UInt64], logN: Int, inverse: Bool) -> [UInt64]? {
        let n = input.count
        
        // 创建数据缓冲区
        guard let dataBuffer = device.makeBuffer(
            bytes: input,
            length: n * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            print("❌ 无法创建数据缓冲区")
            return nil
        }
        
        // 获取或创建旋转因子
        guard let twiddleBuffer = getTwiddleFactors(logN: logN, inverse: inverse) else {
            print("❌ 无法获取旋转因子")
            return nil
        }
        
        // 位反转重排
        if !performBitReverse(dataBuffer, logN: logN) {
            print("❌ 位反转失败")
            return nil
        }
        
        // 执行蝶形运算
        for stage in 0..<logN {
            let stepSize = 1 << stage
            
            guard let commandBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = commandBuffer.makeComputeCommandEncoder() else {
                print("❌ 无法创建命令缓冲区")
                return nil
            }
            
            encoder.setComputePipelineState(nttPipelineState)
            encoder.setBuffer(dataBuffer, offset: 0, index: 0)
            
            var stepSizeVar = UInt32(stepSize)
            var stageVar = UInt32(stage)
            var logNVar = UInt32(logN)
            
            encoder.setBytes(&stepSizeVar, length: MemoryLayout<UInt32>.size, index: 1)
            encoder.setBytes(&stageVar, length: MemoryLayout<UInt32>.size, index: 2)
            encoder.setBytes(&logNVar, length: MemoryLayout<UInt32>.size, index: 3)
            encoder.setBuffer(twiddleBuffer, offset: 0, index: 4)
            
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
            
            if let error = commandBuffer.error {
                print("❌ GPU 计算错误: \(error)")
                return nil
            }
        }
        
        // 如果是逆变换，需要除以 n
        if inverse {
            performFinalDivision(dataBuffer, logN: logN)
        }
        
        // 读取结果
        let resultPointer = dataBuffer.contents().bindMemory(to: UInt64.self, capacity: n)
        return Array(UnsafeBufferPointer(start: resultPointer, count: n))
    }
    
    private func performBitReverse(_ buffer: MTLBuffer, logN: Int) -> Bool {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return false
        }
        
        encoder.setComputePipelineState(bitReversePipelineState)
        encoder.setBuffer(buffer, offset: 0, index: 0)
        
        var logNVar = UInt32(logN)
        encoder.setBytes(&logNVar, length: MemoryLayout<UInt32>.size, index: 1)
        
        let n = 1 << logN
        let threadsPerGroup = MTLSize(width: min(1024, n), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(
            width: (n + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        return commandBuffer.error == nil
    }
    
    private func getTwiddleFactors(logN: Int, inverse: Bool) -> MTLBuffer? {
        let cacheKey = inverse ? -logN : logN
        
        if let cached = twiddleFactorsCache[cacheKey] {
            return cached
        }
        
        let n = 1 << logN
        let twiddleFactors = computeTwiddleFactors(n: n, inverse: inverse)
        
        guard let buffer = device.makeBuffer(
            bytes: twiddleFactors,
            length: twiddleFactors.count * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        twiddleFactorsCache[cacheKey] = buffer
        return buffer
    }
    
    private func computeTwiddleFactors(n: Int, inverse: Bool) -> [UInt64] {
        var factors: [UInt64] = []
        
        let rootOfUnity = inverse ? FieldConstants.rootOfUnityInverse : FieldConstants.rootOfUnity
        
        for i in 0..<(n/2) {
            let factor = FieldMath.powMod(rootOfUnity, UInt64(i), FieldConstants.modulus)
            factors.append(factor)
        }
        
        return factors
    }
    
    private func performFinalDivision(_ buffer: MTLBuffer, logN: Int) {
        // 实现最终的除法操作（逆 NTT 需要）
        let n = UInt64(1 << logN)
        let nInverse = FieldMath.modInverse(n, modulus: FieldConstants.modulus)
        
        // 这里应该调用 GPU 核函数进行批量除法
        // 简化实现：在 CPU 上进行
        let pointer = buffer.contents().bindMemory(to: UInt64.self, capacity: Int(n))
        for i in 0..<Int(n) {
            pointer[i] = FieldMath.mulMod(pointer[i], nInverse, FieldConstants.modulus)
        }
    }
    
    private func performMSM(_ scalars: [UInt64], _ points: [EllipticCurvePoint]) -> EllipticCurvePoint? {
        // MSM 实现
        // 这里是简化版本，实际实现会更复杂
        
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return nil
        }
        
        // 创建缓冲区
        guard let scalarBuffer = device.makeBuffer(
            bytes: scalars,
            length: scalars.count * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        // 点数据需要特殊处理
        let pointData = points.flatMap { [$0.x, $0.y, $0.z] }
        guard let pointBuffer = device.makeBuffer(
            bytes: pointData,
            length: pointData.count * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        // 结果缓冲区
        guard let resultBuffer = device.makeBuffer(
            length: 3 * MemoryLayout<UInt64>.size,
            options: .storageModeShared
        ) else {
            return nil
        }
        
        encoder.setComputePipelineState(msmPipelineState)
        encoder.setBuffer(scalarBuffer, offset: 0, index: 0)
        encoder.setBuffer(pointBuffer, offset: 0, index: 1)
        encoder.setBuffer(resultBuffer, offset: 0, index: 2)
        
        var count = UInt32(scalars.count)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.size, index: 3)
        
        let threadsPerGroup = MTLSize(width: min(256, scalars.count), height: 1, depth: 1)
        let groupsPerGrid = MTLSize(
            width: (scalars.count + threadsPerGroup.width - 1) / threadsPerGroup.width,
            height: 1,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(groupsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        if commandBuffer.error != nil {
            return nil
        }
        
        // 读取结果
        let resultPointer = resultBuffer.contents().bindMemory(to: UInt64.self, capacity: 3)
        return EllipticCurvePoint(
            x: resultPointer[0],
            y: resultPointer[1],
            z: resultPointer[2]
        )
    }
}

// MARK: - Supporting Types

/// 椭圆曲线点
public struct EllipticCurvePoint {
    public let x: UInt64
    public let y: UInt64
    public let z: UInt64  // 齐次坐标
    
    public init(x: UInt64, y: UInt64, z: UInt64 = 1) {
        self.x = x
        self.y = y
        self.z = z
    }
}

/// 有限域常数
private enum FieldConstants {
    static let modulus: UInt64 = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
    static let rootOfUnity: UInt64 = 0x1234567890abcdef  // 需要计算实际值
    static let rootOfUnityInverse: UInt64 = 0xfedcba0987654321  // 需要计算实际值
}

/// 有限域数学运算
private enum FieldMath {
    static func powMod(_ base: UInt64, _ exp: UInt64, _ mod: UInt64) -> UInt64 {
        var result: UInt64 = 1
        var base = base % mod
        var exp = exp
        
        while exp > 0 {
            if exp & 1 == 1 {
                result = mulMod(result, base, mod)
            }
            base = mulMod(base, base, mod)
            exp >>= 1
        }
        
        return result
    }
    
    static func mulMod(_ a: UInt64, _ b: UInt64, _ mod: UInt64) -> UInt64 {
        // 简化实现，实际应该使用 Montgomery 乘法
        return (a * b) % mod
    }
    
    static func modInverse(_ a: UInt64, modulus: UInt64) -> UInt64 {
        // 扩展欧几里得算法
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