# Python-Metal 集成指南

## 概述

本指南介绍如何在 Python 中调用 Metal GPU 计算，实现高性能的 ZKP 运算。

## 环境准备

### 1. 安装依赖

```bash
# 安装 PyObjC（Python-Objective-C 桥接）
pip install pyobjc-framework-Metal
pip install pyobjc-framework-MetalKit
pip install pyobjc-framework-Quartz

# 安装数值计算库
pip install numpy
pip install scipy

# 可选：安装 Jupyter 用于交互式开发
pip install jupyter
```

### 2. 验证安装

```python
# test_metal_setup.py
import sys
try:
    import Metal
    import MetalKit
    print("✅ Metal 框架导入成功")
    
    # 检查设备可用性
    device = Metal.MTLCreateSystemDefaultDevice()
    if device:
        print(f"✅ Metal 设备可用: {device.name()}")
        print(f"   最大线程组大小: {device.maxThreadsPerThreadgroup()}")
        print(f"   推荐工作集大小: {device.recommendedMaxWorkingSetSize() // 1024 // 1024} MB")
    else:
        print("❌ Metal 设备不可用")
        sys.exit(1)
        
except ImportError as e:
    print(f"❌ 导入失败: {e}")
    sys.exit(1)
```

## 基础 Metal-Python 接口

### 1. 设备和队列管理

```python
# metal_manager.py
import Metal
import Foundation
from typing import Optional, List
import numpy as np

class MetalManager:
    """Metal 设备和资源管理器"""
    
    def __init__(self):
        self.device = Metal.MTLCreateSystemDefaultDevice()
        if not self.device:
            raise RuntimeError("Metal 设备不可用")
        
        self.command_queue = self.device.newCommandQueue()
        if not self.command_queue:
            raise RuntimeError("无法创建命令队列")
        
        self.library_cache = {}
        
    def create_buffer_from_numpy(self, array: np.ndarray) -> Metal.MTLBuffer:
        """从 NumPy 数组创建 Metal 缓冲区"""
        # 确保数组是连续的
        if not array.flags.c_contiguous:
            array = np.ascontiguousarray(array)
        
        # 创建缓冲区
        buffer = self.device.newBufferWithBytes_length_options_(
            array.ctypes.data,
            array.nbytes,
            Metal.MTLResourceStorageModeShared
        )
        
        if not buffer:
            raise RuntimeError("缓冲区创建失败")
        
        return buffer
    
    def buffer_to_numpy(self, buffer: Metal.MTLBuffer, 
                       dtype: np.dtype, shape: tuple) -> np.ndarray:
        """将 Metal 缓冲区转换为 NumPy 数组"""
        # 获取缓冲区内容指针
        contents = buffer.contents()
        
        # 创建 NumPy 数组视图
        array = np.frombuffer(
            Foundation.NSData.dataWithBytesNoCopy_length_freeWhenDone_(
                contents, buffer.length(), False
            ),
            dtype=dtype
        ).reshape(shape)
        
        return array.copy()  # 返回副本以避免内存问题
    
    def compile_shader(self, source: str, function_name: str):
        """编译 Metal 着色器"""
        # 检查缓存
        cache_key = hash(source + function_name)
        if cache_key in self.library_cache:
            return self.library_cache[cache_key]
        
        # 编译选项
        options = Metal.MTLCompileOptions.alloc().init()
        options.setFastMathEnabled_(True)
        options.setLanguageVersion_(Metal.MTLLanguageVersion2_4)
        
        # 编译库
        library, error = self.device.newLibraryWithSource_options_error_(
            source, options, None
        )
        
        if error:
            raise RuntimeError(f"着色器编译失败: {error}")
        
        # 获取函数
        function = library.newFunctionWithName_(function_name)
        if not function:
            raise RuntimeError(f"函数 '{function_name}' 未找到")
        
        # 创建计算管道状态
        pipeline_state, error = self.device.newComputePipelineStateWithFunction_error_(
            function, None
        )
        
        if error:
            raise RuntimeError(f"管道状态创建失败: {error}")
        
        # 缓存结果
        result = {
            'library': library,
            'function': function,
            'pipeline_state': pipeline_state
        }
        self.library_cache[cache_key] = result
        
        return result
```

### 2. 有限域运算接口

```python
# field_operations.py
import numpy as np
from metal_manager import MetalManager

class FieldOperations:
    """有限域运算的 Python 接口"""
    
    # BLS12-381 标量域模数
    BLS12_381_SCALAR_MODULUS = [
        0x73eda753299d7d48,
        0x06d89f71cab8351f, 
        0x2833e84879b97091,
        0x30644e72e131a029
    ]
    
    def __init__(self):
        self.metal = MetalManager()
        self._compile_shaders()
    
    def _compile_shaders(self):
        """编译有限域运算着色器"""
        shader_source = '''
        #include <metal_stdlib>
        using namespace metal;
        
        struct FieldElement {
            uint64_t limbs[4];
        };
        
        constant uint64_t MODULUS[4] = {
            0x73eda753299d7d48,
            0x06d89f71cab8351f,
            0x2833e84879b97091,
            0x30644e72e131a029
        };
        
        bool field_gte(FieldElement a, constant uint64_t* modulus) {
            for (int i = 3; i >= 0; i--) {
                if (a.limbs[i] > modulus[i]) return true;
                if (a.limbs[i] < modulus[i]) return false;
            }
            return true;  // 相等
        }
        
        FieldElement field_sub(FieldElement a, constant uint64_t* modulus) {
            FieldElement result;
            uint64_t borrow = 0;
            
            for (int i = 0; i < 4; i++) {
                uint64_t temp = a.limbs[i] - modulus[i] - borrow;
                result.limbs[i] = temp;
                borrow = (temp > a.limbs[i]) ? 1 : 0;
            }
            
            return result;
        }
        
        kernel void field_add_kernel(
            device const FieldElement* a [[buffer(0)]],
            device const FieldElement* b [[buffer(1)]],
            device FieldElement* result [[buffer(2)]],
            uint gid [[thread_position_in_grid]]
        ) {
            FieldElement temp_result;
            uint64_t carry = 0;
            
            // 加法
            for (int i = 0; i < 4; i++) {
                uint64_t sum = a[gid].limbs[i] + b[gid].limbs[i] + carry;
                temp_result.limbs[i] = sum;
                carry = (sum < a[gid].limbs[i]) ? 1 : 0;
            }
            
            // 条件减法
            if (carry > 0 || field_gte(temp_result, MODULUS)) {
                temp_result = field_sub(temp_result, MODULUS);
            }
            
            result[gid] = temp_result;
        }
        
        kernel void field_mul_kernel(
            device const FieldElement* a [[buffer(0)]],
            device const FieldElement* b [[buffer(1)]],
            device FieldElement* result [[buffer(2)]],
            uint gid [[thread_position_in_grid]]
        ) {
            // 蒙哥马利乘法实现
            uint64_t t[8] = {0};
            
            // 第一阶段：计算 a * b
            for (int i = 0; i < 4; i++) {
                uint64_t carry = 0;
                for (int j = 0; j < 4; j++) {
                    // 64位乘法，产生128位结果
                    uint64_t prod_low = a[gid].limbs[i] * b[gid].limbs[j];
                    uint64_t prod_high = mulhi(a[gid].limbs[i], b[gid].limbs[j]);
                    
                    uint64_t sum = t[i + j] + prod_low + carry;
                    t[i + j] = sum;
                    carry = prod_high + (sum < t[i + j] ? 1 : 0);
                }
                t[i + 4] = carry;
            }
            
            // 第二阶段：蒙哥马利约简
            // 这里简化实现，实际需要完整的蒙哥马利约简
            FieldElement temp_result;
            for (int i = 0; i < 4; i++) {
                temp_result.limbs[i] = t[i + 4];
            }
            
            // 最终约简
            if (field_gte(temp_result, MODULUS)) {
                temp_result = field_sub(temp_result, MODULUS);
            }
            
            result[gid] = temp_result;
        }
        '''
        
        self.add_shader = self.metal.compile_shader(shader_source, "field_add_kernel")
        self.mul_shader = self.metal.compile_shader(shader_source, "field_mul_kernel")
    
    def add(self, a: np.ndarray, b: np.ndarray) -> np.ndarray:
        """有限域加法"""
        assert a.shape == b.shape, "输入数组形状必须相同"
        assert a.dtype == np.uint64 and b.dtype == np.uint64, "输入必须是 uint64 类型"
        
        # 重塑为 (n, 4) 形状，每行代表一个域元素
        n = a.size // 4
        a_reshaped = a.reshape(n, 4)
        b_reshaped = b.reshape(n, 4)
        
        # 创建缓冲区
        buffer_a = self.metal.create_buffer_from_numpy(a_reshaped)
        buffer_b = self.metal.create_buffer_from_numpy(b_reshaped)
        
        # 结果缓冲区
        result_buffer = self.metal.device.newBufferWithLength_options_(
            a_reshaped.nbytes,
            Metal.MTLResourceStorageModeShared
        )
        
        # 创建命令缓冲区
        command_buffer = self.metal.command_queue.commandBuffer()
        compute_encoder = command_buffer.computeCommandEncoder()
        
        # 设置计算管道
        compute_encoder.setComputePipelineState_(self.add_shader['pipeline_state'])
        compute_encoder.setBuffer_offset_atIndex_(buffer_a, 0, 0)
        compute_encoder.setBuffer_offset_atIndex_(buffer_b, 0, 1)
        compute_encoder.setBuffer_offset_atIndex_(result_buffer, 0, 2)
        
        # 配置线程
        threads_per_threadgroup = Metal.MTLSize(256, 1, 1)
        threadgroups = Metal.MTLSize(
            (n + 255) // 256,  # 向上取整
            1, 1
        )
        
        compute_encoder.dispatchThreadgroups_threadsPerThreadgroup_(
            threadgroups, threads_per_threadgroup
        )
        compute_encoder.endEncoding()
        
        # 执行
        command_buffer.commit()
        command_buffer.waitUntilCompleted()
        
        # 获取结果
        result = self.metal.buffer_to_numpy(
            result_buffer, 
            np.uint64, 
            a_reshaped.shape
        )
        
        return result.reshape(a.shape)
    
    def multiply(self, a: np.ndarray, b: np.ndarray) -> np.ndarray:
        """有限域乘法"""
        # 实现类似于 add 方法
        # 这里省略具体实现，结构相同
        pass
```

### 3. NTT 计算接口

```python
# ntt_operations.py
import numpy as np
from metal_manager import MetalManager

class NTTOperations:
    """数论变换的 Python 接口"""
    
    def __init__(self):
        self.metal = MetalManager()
        self._compile_ntt_shaders()
        self._precompute_twiddle_factors()
    
    def _compile_ntt_shaders(self):
        """编译 NTT 着色器"""
        ntt_shader_source = '''
        #include <metal_stdlib>
        using namespace metal;
        
        struct FieldElement {
            uint64_t limbs[4];
        };
        
        // 域元素运算函数（省略具体实现）
        FieldElement field_add(FieldElement a, FieldElement b);
        FieldElement field_sub(FieldElement a, FieldElement b);
        FieldElement field_mul(FieldElement a, FieldElement b);
        
        kernel void ntt_kernel(
            device FieldElement* data [[buffer(0)]],
            device const FieldElement* twiddle_factors [[buffer(1)]],
            constant uint& stage [[buffer(2)]],
            constant uint& n [[buffer(3)]],
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
        '''
        
        self.ntt_shader = self.metal.compile_shader(ntt_shader_source, "ntt_kernel")
    
    def _precompute_twiddle_factors(self):
        """预计算旋转因子"""
        # 这里应该预计算各种大小的旋转因子
        # 简化实现
        self.twiddle_factors_cache = {}
    
    def forward_ntt(self, data: np.ndarray) -> np.ndarray:
        """前向 NTT"""
        n = len(data)
        assert n & (n - 1) == 0, "数据长度必须是 2 的幂"
        
        # 创建数据缓冲区
        data_buffer = self.metal.create_buffer_from_numpy(data)
        
        # 获取或创建旋转因子
        twiddle_buffer = self._get_twiddle_factors(n)
        
        # 执行 NTT 的各个阶段
        log_n = int(np.log2(n))
        
        for stage in range(log_n):
            command_buffer = self.metal.command_queue.commandBuffer()
            compute_encoder = command_buffer.computeCommandEncoder()
            
            compute_encoder.setComputePipelineState_(self.ntt_shader['pipeline_state'])
            compute_encoder.setBuffer_offset_atIndex_(data_buffer, 0, 0)
            compute_encoder.setBuffer_offset_atIndex_(twiddle_buffer, 0, 1)
            
            # 设置常量
            stage_data = np.array([stage], dtype=np.uint32)
            n_data = np.array([n], dtype=np.uint32)
            
            stage_buffer = self.metal.create_buffer_from_numpy(stage_data)
            n_buffer = self.metal.create_buffer_from_numpy(n_data)
            
            compute_encoder.setBuffer_offset_atIndex_(stage_buffer, 0, 2)
            compute_encoder.setBuffer_offset_atIndex_(n_buffer, 0, 3)
            
            # 配置线程
            m = n >> (stage + 1)
            threads_per_threadgroup = Metal.MTLSize(min(m, 256), 1, 1)
            threadgroups = Metal.MTLSize((m + 255) // 256, 1, 1)
            
            compute_encoder.dispatchThreadgroups_threadsPerThreadgroup_(
                threadgroups, threads_per_threadgroup
            )
            compute_encoder.endEncoding()
            
            command_buffer.commit()
            command_buffer.waitUntilCompleted()
        
        # 获取结果
        result = self.metal.buffer_to_numpy(data_buffer, data.dtype, data.shape)
        return result
    
    def _get_twiddle_factors(self, n: int):
        """获取指定大小的旋转因子缓冲区"""
        if n not in self.twiddle_factors_cache:
            # 计算旋转因子
            twiddle_factors = self._compute_twiddle_factors(n)
            self.twiddle_factors_cache[n] = self.metal.create_buffer_from_numpy(
                twiddle_factors
            )
        
        return self.twiddle_factors_cache[n]
    
    def _compute_twiddle_factors(self, n: int) -> np.ndarray:
        """计算 NTT 旋转因子"""
        # 这里应该计算实际的旋转因子
        # 简化实现，返回占位符
        return np.zeros((n // 2, 4), dtype=np.uint64)
```

## 高级功能

### 1. 批处理操作

```python
# batch_operations.py
from typing import List, Callable, Any
import numpy as np

class BatchProcessor:
    """批处理操作管理器"""
    
    def __init__(self, metal_manager: MetalManager, batch_size: int = 1024):
        self.metal = metal_manager
        self.batch_size = batch_size
    
    def process_batches(self, 
                       data: np.ndarray,
                       operation: Callable[[np.ndarray], np.ndarray]) -> np.ndarray:
        """分批处理大数据集"""
        n = len(data)
        results = []
        
        for i in range(0, n, self.batch_size):
            end = min(i + self.batch_size, n)
            batch = data[i:end]
            
            result = operation(batch)
            results.append(result)
        
        return np.concatenate(results)
    
    def parallel_process(self,
                        data_list: List[np.ndarray],
                        operation: Callable[[np.ndarray], np.ndarray]) -> List[np.ndarray]:
        """并行处理多个数据集"""
        # 使用多个命令缓冲区实现并行
        command_buffers = []
        results = []
        
        for data in data_list:
            # 为每个数据集创建独立的命令缓冲区
            command_buffer = self.metal.command_queue.commandBuffer()
            
            # 这里需要修改 operation 以接受命令缓冲区
            # 简化实现
            result = operation(data)
            results.append(result)
        
        return results
```

### 2. 性能监控

```python
# performance_monitor.py
import time
from typing import Dict, List
import numpy as np

class PerformanceMonitor:
    """性能监控和分析"""
    
    def __init__(self):
        self.metrics: Dict[str, List[float]] = {}
    
    def time_operation(self, name: str, operation: Callable[[], Any]) -> Any:
        """测量操作执行时间"""
        start_time = time.perf_counter()
        result = operation()
        end_time = time.perf_counter()
        
        duration = (end_time - start_time) * 1000  # 转换为毫秒
        
        if name not in self.metrics:
            self.metrics[name] = []
        self.metrics[name].append(duration)
        
        return result
    
    def benchmark_field_operations(self, field_ops: FieldOperations, 
                                 sizes: List[int]) -> Dict[str, Dict[int, float]]:
        """基准测试有限域运算"""
        results = {'add': {}, 'multiply': {}}
        
        for size in sizes:
            # 生成测试数据
            a = np.random.randint(0, 2**64, size=(size, 4), dtype=np.uint64)
            b = np.random.randint(0, 2**64, size=(size, 4), dtype=np.uint64)
            
            # 测试加法
            add_time = self.time_operation(
                f"field_add_{size}",
                lambda: field_ops.add(a, b)
            )
            results['add'][size] = add_time
            
            # 测试乘法
            mul_time = self.time_operation(
                f"field_mul_{size}",
                lambda: field_ops.multiply(a, b)
            )
            results['multiply'][size] = mul_time
        
        return results
    
    def print_summary(self):
        """打印性能摘要"""
        print("=== 性能监控摘要 ===")
        for name, times in self.metrics.items():
            avg_time = np.mean(times)
            min_time = np.min(times)
            max_time = np.max(times)
            
            print(f"{name}:")
            print(f"  平均: {avg_time:.2f} ms")
            print(f"  最小: {min_time:.2f} ms") 
            print(f"  最大: {max_time:.2f} ms")
            print(f"  样本数: {len(times)}")
```

## 使用示例

### 1. 基本使用

```python
# example_basic.py
import numpy as np
from field_operations import FieldOperations
from ntt_operations import NTTOperations

def main():
    # 初始化
    field_ops = FieldOperations()
    ntt_ops = NTTOperations()
    
    # 创建测试数据
    size = 1024
    a = np.random.randint(0, 2**32, size=(size, 4), dtype=np.uint64)
    b = np.random.randint(0, 2**32, size=(size, 4), dtype=np.uint64)
    
    # 有限域加法
    print("执行有限域加法...")
    result_add = field_ops.add(a, b)
    print(f"加法完成，结果形状: {result_add.shape}")
    
    # NTT 变换
    print("执行 NTT 变换...")
    ntt_data = np.random.randint(0, 2**32, size=(1024, 4), dtype=np.uint64)
    ntt_result = ntt_ops.forward_ntt(ntt_data)
    print(f"NTT 完成，结果形状: {ntt_result.shape}")

if __name__ == "__main__":
    main()
```

### 2. 性能测试

```python
# example_benchmark.py
from performance_monitor import PerformanceMonitor
from field_operations import FieldOperations

def main():
    monitor = PerformanceMonitor()
    field_ops = FieldOperations()
    
    # 测试不同大小的性能
    sizes = [256, 512, 1024, 2048, 4096]
    
    print("开始性能基准测试...")
    results = monitor.benchmark_field_operations(field_ops, sizes)
    
    # 打印结果
    print("\n=== 基准测试结果 ===")
    for operation, size_results in results.items():
        print(f"\n{operation.upper()} 运算:")
        for size, time_ms in size_results.items():
            throughput = size / (time_ms / 1000)  # 元素/秒
            print(f"  大小 {size:4d}: {time_ms:6.2f} ms ({throughput:8.0f} 元素/秒)")
    
    monitor.print_summary()

if __name__ == "__main__":
    main()
```

## 注意事项

### 1. 内存管理

- 及时释放大的 Metal 缓冲区
- 使用内存池避免频繁分配
- 监控内存使用情况

### 2. 错误处理

- 检查 Metal 设备可用性
- 验证着色器编译结果
- 处理计算超时情况

### 3. 性能优化

- 批处理小操作
- 重用编译的着色器
- 使用异步计算避免阻塞

这个 Python-Metal 桥接为 ZKP 计算提供了高级接口，同时保持了 GPU 计算的高性能。