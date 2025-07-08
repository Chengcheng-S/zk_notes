#!/usr/bin/env python3
"""
简单的零知识证明示例 - 使用 Mac GPU 加速

这个示例演示如何使用 Metal GPU 加速来生成和验证一个简单的零知识证明。
证明声明：证明者知道一个数 x，使得 x^2 = y (mod p)，但不泄露 x 的值。
"""

import sys
import os
import time
import numpy as np
from typing import Tuple, Optional

# 添加父目录到路径以导入我们的模块
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

try:
    import Metal
    import Foundation
except ImportError:
    print("❌ 错误: 无法导入 Metal 框架")
    print("请确保在 macOS 上运行，并安装了 PyObjC:")
    print("pip install pyobjc-framework-Metal")
    sys.exit(1)

class SimpleZKPProver:
    """简单的零知识证明生成器"""
    
    def __init__(self):
        # 初始化 Metal 设备
        self.device = Metal.MTLCreateSystemDefaultDevice()
        if not self.device:
            raise RuntimeError("Metal 设备不可用")
        
        self.command_queue = self.device.newCommandQueue()
        print(f"✅ 使用 Metal 设备: {self.device.name()}")
        
        # 使用一个小的素数用于演示
        self.prime = 2**31 - 1  # 梅森素数
        
        # 编译 Metal 着色器
        self._compile_shaders()
    
    def _compile_shaders(self):
        """编译用于模运算的 Metal 着色器"""
        shader_source = '''
        #include <metal_stdlib>
        using namespace metal;
        
        // 模乘法
        kernel void mod_multiply(
            device const uint64_t* a [[buffer(0)]],
            device const uint64_t* b [[buffer(1)]],
            device uint64_t* result [[buffer(2)]],
            constant uint64_t& modulus [[buffer(3)]],
            uint gid [[thread_position_in_grid]]
        ) {
            uint64_t prod = a[gid] * b[gid];
            result[gid] = prod % modulus;
        }
        
        // 模幂运算 (简化版本，仅用于演示)
        kernel void mod_power(
            device const uint64_t* base [[buffer(0)]],
            device const uint64_t* exponent [[buffer(1)]],
            device uint64_t* result [[buffer(2)]],
            constant uint64_t& modulus [[buffer(3)]],
            uint gid [[thread_position_in_grid]]
        ) {
            uint64_t b = base[gid];
            uint64_t e = exponent[gid];
            uint64_t res = 1;
            
            b = b % modulus;
            
            while (e > 0) {
                if (e & 1) {
                    res = (res * b) % modulus;
                }
                e = e >> 1;
                b = (b * b) % modulus;
            }
            
            result[gid] = res;
        }
        '''
        
        # 编译选项
        options = Metal.MTLCompileOptions.alloc().init()
        options.setFastMathEnabled_(True)
        
        # 编译库
        library, error = self.device.newLibraryWithSource_options_error_(
            shader_source, options, None
        )
        
        if error:
            raise RuntimeError(f"着色器编译失败: {error}")
        
        # 获取函数
        self.mod_multiply_function = library.newFunctionWithName_("mod_multiply")
        self.mod_power_function = library.newFunctionWithName_("mod_power")
        
        # 创建计算管道状态
        self.mod_multiply_pipeline, error = self.device.newComputePipelineStateWithFunction_error_(
            self.mod_multiply_function, None
        )
        if error:
            raise RuntimeError(f"乘法管道创建失败: {error}")
        
        self.mod_power_pipeline, error = self.device.newComputePipelineStateWithFunction_error_(
            self.mod_power_function, None
        )
        if error:
            raise RuntimeError(f"幂运算管道创建失败: {error}")
    
    def _create_buffer_from_array(self, array: np.ndarray) -> Metal.MTLBuffer:
        """从 NumPy 数组创建 Metal 缓冲区"""
        if not array.flags.c_contiguous:
            array = np.ascontiguousarray(array)
        
        buffer = self.device.newBufferWithBytes_length_options_(
            array.ctypes.data,
            array.nbytes,
            Metal.MTLResourceStorageModeShared
        )
        
        if not buffer:
            raise RuntimeError("缓冲区创建失败")
        
        return buffer
    
    def _buffer_to_array(self, buffer: Metal.MTLBuffer, dtype: np.dtype, shape: tuple) -> np.ndarray:
        """将 Metal 缓冲区转换为 NumPy 数组"""
        contents = buffer.contents()
        array = np.frombuffer(
            Foundation.NSData.dataWithBytesNoCopy_length_freeWhenDone_(
                contents, buffer.length(), False
            ),
            dtype=dtype
        ).reshape(shape)
        return array.copy()
    
    def gpu_mod_power(self, bases: np.ndarray, exponents: np.ndarray) -> np.ndarray:
        """使用 GPU 计算模幂运算"""
        assert len(bases) == len(exponents), "输入数组长度必须相同"
        
        # 确保数据类型正确
        bases = bases.astype(np.uint64)
        exponents = exponents.astype(np.uint64)
        
        # 创建缓冲区
        base_buffer = self._create_buffer_from_array(bases)
        exp_buffer = self._create_buffer_from_array(exponents)
        
        result_buffer = self.device.newBufferWithLength_options_(
            bases.nbytes,
            Metal.MTLResourceStorageModeShared
        )
        
        modulus_array = np.array([self.prime], dtype=np.uint64)
        modulus_buffer = self._create_buffer_from_array(modulus_array)
        
        # 创建命令缓冲区
        command_buffer = self.command_queue.commandBuffer()
        compute_encoder = command_buffer.computeCommandEncoder()
        
        # 设置计算管道
        compute_encoder.setComputePipelineState_(self.mod_power_pipeline)
        compute_encoder.setBuffer_offset_atIndex_(base_buffer, 0, 0)
        compute_encoder.setBuffer_offset_atIndex_(exp_buffer, 0, 1)
        compute_encoder.setBuffer_offset_atIndex_(result_buffer, 0, 2)
        compute_encoder.setBuffer_offset_atIndex_(modulus_buffer, 0, 3)
        
        # 配置线程
        n = len(bases)
        threads_per_threadgroup = Metal.MTLSize(min(n, 256), 1, 1)
        threadgroups = Metal.MTLSize((n + 255) // 256, 1, 1)
        
        compute_encoder.dispatchThreadgroups_threadsPerThreadgroup_(
            threadgroups, threads_per_threadgroup
        )
        compute_encoder.endEncoding()
        
        # 执行
        start_time = time.perf_counter()
        command_buffer.commit()
        command_buffer.waitUntilCompleted()
        end_time = time.perf_counter()
        
        print(f"GPU 计算耗时: {(end_time - start_time) * 1000:.2f} ms")
        
        # 获取结果
        result = self._buffer_to_array(result_buffer, np.uint64, bases.shape)
        return result
    
    def cpu_mod_power(self, bases: np.ndarray, exponents: np.ndarray) -> np.ndarray:
        """使用 CPU 计算模幂运算（用于对比）"""
        start_time = time.perf_counter()
        result = np.array([pow(int(b), int(e), self.prime) for b, e in zip(bases, exponents)], dtype=np.uint64)
        end_time = time.perf_counter()
        
        print(f"CPU 计算耗时: {(end_time - start_time) * 1000:.2f} ms")
        return result
    
    def generate_proof(self, secret: int, public_value: int) -> dict:
        """
        生成零知识证明
        证明：知道 secret，使得 secret^2 ≡ public_value (mod prime)
        """
        print(f"\n🔐 生成零知识证明...")
        print(f"秘密值: {secret}")
        print(f"公开值: {public_value}")
        print(f"模数: {self.prime}")
        
        # 验证关系
        expected = pow(secret, 2, self.prime)
        if expected != public_value:
            raise ValueError(f"无效的输入: {secret}^2 mod {self.prime} = {expected} ≠ {public_value}")
        
        # 生成随机数用于零知识性
        r = np.random.randint(1, self.prime - 1)
        
        # 第一轮：承诺
        # 计算 commitment = r^2 mod prime
        commitment_gpu = self.gpu_mod_power(np.array([r]), np.array([2]))[0]
        
        print(f"随机数 r: {r}")
        print(f"承诺值: {commitment_gpu}")
        
        # 模拟 Fiat-Shamir 变换（在实际应用中应该使用哈希函数）
        challenge = hash(f"{public_value}{commitment_gpu}") % (2**16)  # 简化的挑战
        
        print(f"挑战值: {challenge}")
        
        # 第二轮：响应
        if challenge % 2 == 0:
            # 挑战为偶数：返回 r
            response = r
            response_type = "r"
        else:
            # 挑战为奇数：返回 r * secret mod prime
            response = (r * secret) % self.prime
            response_type = "r*secret"
        
        print(f"响应: {response} (类型: {response_type})")
        
        proof = {
            'commitment': int(commitment_gpu),
            'challenge': challenge,
            'response': response,
            'response_type': response_type,
            'public_value': public_value
        }
        
        return proof
    
    def verify_proof(self, proof: dict) -> bool:
        """验证零知识证明"""
        print(f"\n🔍 验证零知识证明...")
        
        commitment = proof['commitment']
        challenge = proof['challenge']
        response = proof['response']
        response_type = proof['response_type']
        public_value = proof['public_value']
        
        print(f"承诺值: {commitment}")
        print(f"挑战值: {challenge}")
        print(f"响应: {response}")
        print(f"响应类型: {response_type}")
        
        # 验证响应
        if response_type == "r":
            # 验证 response^2 ≡ commitment (mod prime)
            expected_gpu = self.gpu_mod_power(np.array([response]), np.array([2]))[0]
            valid = (expected_gpu == commitment)
            print(f"验证: {response}^2 mod {self.prime} = {expected_gpu}")
            print(f"期望: {commitment}")
        else:  # response_type == "r*secret"
            # 验证 response^2 ≡ commitment * public_value (mod prime)
            response_squared_gpu = self.gpu_mod_power(np.array([response]), np.array([2]))[0]
            expected = (commitment * public_value) % self.prime
            valid = (response_squared_gpu == expected)
            print(f"验证: {response}^2 mod {self.prime} = {response_squared_gpu}")
            print(f"期望: {commitment} * {public_value} mod {self.prime} = {expected}")
        
        result = "✅ 验证通过" if valid else "❌ 验证失败"
        print(f"结果: {result}")
        
        return valid

def performance_comparison():
    """性能对比测试"""
    print("\n📊 GPU vs CPU 性能对比")
    print("=" * 50)
    
    prover = SimpleZKPProver()
    
    # 测试不同大小的数据集
    sizes = [100, 500, 1000, 5000]
    
    for size in sizes:
        print(f"\n测试大小: {size}")
        
        # 生成随机数据
        bases = np.random.randint(1, 1000, size, dtype=np.uint64)
        exponents = np.random.randint(1, 100, size, dtype=np.uint64)
        
        # GPU 计算
        print("GPU 计算:")
        gpu_result = prover.gpu_mod_power(bases, exponents)
        
        # CPU 计算
        print("CPU 计算:")
        cpu_result = prover.cpu_mod_power(bases, exponents)
        
        # 验证结果一致性
        if np.array_equal(gpu_result, cpu_result):
            print("✅ GPU 和 CPU 结果一致")
        else:
            print("❌ GPU 和 CPU 结果不一致")
            print(f"差异数量: {np.sum(gpu_result != cpu_result)}")

def main():
    """主函数"""
    print("🚀 简单零知识证明演示 - Mac GPU 加速")
    print("=" * 60)
    
    try:
        # 创建证明者
        prover = SimpleZKPProver()
        
        # 示例：证明知道 x = 123，使得 x^2 ≡ y (mod prime)
        secret = 123
        public_value = pow(secret, 2, prover.prime)
        
        # 生成证明
        proof = prover.generate_proof(secret, public_value)
        
        # 验证证明
        is_valid = prover.verify_proof(proof)
        
        if is_valid:
            print("\n🎉 零知识证明演示成功！")
        else:
            print("\n💥 零知识证明验证失败！")
        
        # 性能对比
        performance_comparison()
        
    except Exception as e:
        print(f"\n❌ 错误: {e}")
        import traceback
        traceback.print_exc()
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(main())