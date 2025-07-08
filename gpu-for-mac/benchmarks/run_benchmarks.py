#!/usr/bin/env python3
"""
ZKP Metal 性能基准测试

这个脚本运行各种 ZKP 算法的性能测试，比较 CPU 和 GPU 实现的性能。
"""

import time
import sys
import os
import argparse
import json
from typing import List, Dict, Any, Tuple
import platform

# 添加项目路径
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'python-bindings'))

try:
    import zkp_metal
    import numpy as np
    METAL_AVAILABLE = True
except ImportError as e:
    print(f"❌ 无法导入 zkp_metal: {e}")
    METAL_AVAILABLE = False

class BenchmarkRunner:
    """基准测试运行器"""
    
    def __init__(self):
        self.results = {}
        self.metal_engine = None
        
        if METAL_AVAILABLE:
            try:
                self.metal_engine = zkp_metal.MetalEngine()
                print("✅ Metal 引擎初始化成功")
            except Exception as e:
                print(f"❌ Metal 引擎初始化失败: {e}")
                METAL_AVAILABLE = False
    
    def benchmark_ntt(self, sizes: List[int], iterations: int = 10) -> Dict[str, Any]:
        """NTT 性能测试"""
        print("\n🔄 NTT 性能测试")
        print("-" * 50)
        print(f"{'大小':<10} {'CPU时间':<12} {'GPU时间':<12} {'加速比':<8} {'验证':<6}")
        print("-" * 50)
        
        results = {}
        
        for size in sizes:
            if size & (size - 1) != 0:  # 检查是否为 2 的幂
                print(f"⚠️  跳过 {size}，不是 2 的幂")
                continue
            
            # 生成测试数据
            data = self._generate_random_data(size)
            
            # CPU 基准测试
            cpu_time = self._benchmark_cpu_ntt(data, iterations)
            
            # GPU 基准测试
            gpu_time = None
            gpu_result = None
            if METAL_AVAILABLE and self.metal_engine:
                gpu_time, gpu_result = self._benchmark_gpu_ntt(data, iterations)
            
            # 验证结果
            verification = "N/A"
            if gpu_result is not None:
                cpu_result = self._cpu_ntt(data)
                verification = "✅" if self._verify_results(cpu_result, gpu_result) else "❌"
            
            # 计算加速比
            speedup = cpu_time / gpu_time if gpu_time else 0
            
            # 显示结果
            cpu_str = f"{cpu_time*1000:.1f}ms" if cpu_time else "N/A"
            gpu_str = f"{gpu_time*1000:.1f}ms" if gpu_time else "N/A"
            speedup_str = f"{speedup:.1f}x" if speedup > 0 else "N/A"
            
            print(f"{size:<10} {cpu_str:<12} {gpu_str:<12} {speedup_str:<8} {verification:<6}")
            
            results[size] = {
                'cpu_time': cpu_time,
                'gpu_time': gpu_time,
                'speedup': speedup,
                'verified': verification == "✅"
            }
        
        return results
    
    def benchmark_msm(self, sizes: List[int], iterations: int = 5) -> Dict[str, Any]:
        """MSM 性能测试"""
        print("\n🔄 MSM 性能测试")
        print("-" * 50)
        print(f"{'大小':<10} {'CPU时间':<12} {'GPU时间':<12} {'加速比':<8} {'验证':<6}")
        print("-" * 50)
        
        results = {}
        
        for size in sizes:
            # 生成测试数据
            scalars = self._generate_random_scalars(size)
            points = self._generate_random_points(size)
            
            # CPU 基准测试
            cpu_time = self._benchmark_cpu_msm(scalars, points, iterations)
            
            # GPU 基准测试
            gpu_time = None
            gpu_result = None
            if METAL_AVAILABLE and self.metal_engine:
                gpu_time, gpu_result = self._benchmark_gpu_msm(scalars, points, iterations)
            
            # 验证结果
            verification = "N/A"
            if gpu_result is not None:
                cpu_result = self._cpu_msm(scalars, points)
                verification = "✅" if self._verify_points(cpu_result, gpu_result) else "❌"
            
            # 计算加速比
            speedup = cpu_time / gpu_time if gpu_time else 0
            
            # 显示结果
            cpu_str = f"{cpu_time*1000:.1f}ms" if cpu_time else "N/A"
            gpu_str = f"{gpu_time*1000:.1f}ms" if gpu_time else "N/A"
            speedup_str = f"{speedup:.1f}x" if speedup > 0 else "N/A"
            
            print(f"{size:<10} {cpu_str:<12} {gpu_str:<12} {speedup_str:<8} {verification:<6}")
            
            results[size] = {
                'cpu_time': cpu_time,
                'gpu_time': gpu_time,
                'speedup': speedup,
                'verified': verification == "✅"
            }
        
        return results
    
    def benchmark_polynomial_multiply(self, sizes: List[int], iterations: int = 10) -> Dict[str, Any]:
        """多项式乘法性能测试"""
        print("\n🔄 多项式乘法性能测试")
        print("-" * 60)
        print(f"{'大小':<10} {'CPU时间':<12} {'GPU时间':<12} {'加速比':<8} {'验证':<6}")
        print("-" * 60)
        
        results = {}
        
        for size in sizes:
            # 生成测试数据
            poly_a = self._generate_random_data(size)
            poly_b = self._generate_random_data(size)
            
            # CPU 基准测试
            cpu_time = self._benchmark_cpu_poly_mul(poly_a, poly_b, iterations)
            
            # GPU 基准测试
            gpu_time = None
            gpu_result = None
            if METAL_AVAILABLE and self.metal_engine:
                gpu_time, gpu_result = self._benchmark_gpu_poly_mul(poly_a, poly_b, iterations)
            
            # 验证结果
            verification = "N/A"
            if gpu_result is not None:
                cpu_result = self._cpu_poly_multiply(poly_a, poly_b)
                verification = "✅" if self._verify_results(cpu_result, gpu_result) else "❌"
            
            # 计算加速比
            speedup = cpu_time / gpu_time if gpu_time else 0
            
            # 显示结果
            cpu_str = f"{cpu_time*1000:.1f}ms" if cpu_time else "N/A"
            gpu_str = f"{gpu_time*1000:.1f}ms" if gpu_time else "N/A"
            speedup_str = f"{speedup:.1f}x" if speedup > 0 else "N/A"
            
            print(f"{size:<10} {cpu_str:<12} {gpu_str:<12} {speedup_str:<8} {verification:<6}")
            
            results[size] = {
                'cpu_time': cpu_time,
                'gpu_time': gpu_time,
                'speedup': speedup,
                'verified': verification == "✅"
            }
        
        return results
    
    def run_memory_benchmark(self) -> Dict[str, Any]:
        """内存使用基准测试"""
        print("\n🔄 内存使用测试")
        print("-" * 40)
        
        if not METAL_AVAILABLE or not self.metal_engine:
            print("❌ Metal 不可用，跳过内存测试")
            return {}
        
        import psutil
        import gc
        
        results = {}
        sizes = [1024, 4096, 16384, 65536]
        
        for size in sizes:
            # 测量前清理内存
            gc.collect()
            
            # 记录初始内存
            process = psutil.Process()
            initial_memory = process.memory_info().rss / 1024 / 1024  # MB
            
            # 执行操作
            data = self._generate_random_data(size)
            result = self.metal_engine.ntt(data)
            
            # 记录峰值内存
            peak_memory = process.memory_info().rss / 1024 / 1024  # MB
            memory_used = peak_memory - initial_memory
            
            print(f"大小 {size}: 使用内存 {memory_used:.1f} MB")
            
            results[size] = {
                'memory_used_mb': memory_used,
                'memory_per_element_kb': (memory_used * 1024) / size
            }
            
            # 清理
            del data, result
            gc.collect()
        
        return results
    
    def _generate_random_data(self, size: int) -> List[int]:
        """生成随机测试数据"""
        np.random.seed(42)  # 固定种子以便重现
        modulus = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001
        return [int(x) for x in np.random.randint(0, modulus, size)]
    
    def _generate_random_scalars(self, size: int) -> List[int]:
        """生成随机标量"""
        return self._generate_random_data(size)
    
    def _generate_random_points(self, size: int) -> List[Any]:
        """生成随机椭圆曲线点"""
        if METAL_AVAILABLE:
            return zkp_metal.generate_random_points(size)
        else:
            # 简化的点表示
            return [(i, i*2, 1) for i in range(size)]
    
    def _benchmark_cpu_ntt(self, data: List[int], iterations: int) -> float:
        """CPU NTT 基准测试"""
        start_time = time.time()
        for _ in range(iterations):
            result = self._cpu_ntt(data)
        end_time = time.time()
        return (end_time - start_time) / iterations
    
    def _benchmark_gpu_ntt(self, data: List[int], iterations: int) -> Tuple[float, List[int]]:
        """GPU NTT 基准测试"""
        start_time = time.time()
        result = None
        for _ in range(iterations):
            result = self.metal_engine.ntt(data)
        end_time = time.time()
        return (end_time - start_time) / iterations, result
    
    def _benchmark_cpu_msm(self, scalars: List[int], points: List[Any], iterations: int) -> float:
        """CPU MSM 基准测试"""
        start_time = time.time()
        for _ in range(iterations):
            result = self._cpu_msm(scalars, points)
        end_time = time.time()
        return (end_time - start_time) / iterations
    
    def _benchmark_gpu_msm(self, scalars: List[int], points: List[Any], iterations: int) -> Tuple[float, Any]:
        """GPU MSM 基准测试"""
        start_time = time.time()
        result = None
        for _ in range(iterations):
            result = self.metal_engine.msm(scalars, points)
        end_time = time.time()
        return (end_time - start_time) / iterations, result
    
    def _benchmark_cpu_poly_mul(self, a: List[int], b: List[int], iterations: int) -> float:
        """CPU 多项式乘法基准测试"""
        start_time = time.time()
        for _ in range(iterations):
            result = self._cpu_poly_multiply(a, b)
        end_time = time.time()
        return (end_time - start_time) / iterations
    
    def _benchmark_gpu_poly_mul(self, a: List[int], b: List[int], iterations: int) -> Tuple[float, List[int]]:
        """GPU 多项式乘法基准测试"""
        start_time = time.time()
        result = None
        for _ in range(iterations):
            result = self.metal_engine.polynomial_multiply(a, b)
        end_time = time.time()
        return (end_time - start_time) / iterations, result
    
    def _cpu_ntt(self, data: List[int]) -> List[int]:
        """CPU NTT 参考实现"""
        # 简化的 NTT 实现
        n = len(data)
        if n <= 1:
            return data
        
        # 递归 NTT (简化版本)
        even = self._cpu_ntt([data[i] for i in range(0, n, 2)])
        odd = self._cpu_ntt([data[i] for i in range(1, n, 2)])
        
        result = [0] * n
        for i in range(n // 2):
            t = odd[i]  # 简化：省略旋转因子
            result[i] = (even[i] + t) % zkp_metal.BLS12_381_MODULUS
            result[i + n // 2] = (even[i] - t) % zkp_metal.BLS12_381_MODULUS
        
        return result
    
    def _cpu_msm(self, scalars: List[int], points: List[Any]) -> Any:
        """CPU MSM 参考实现"""
        # 简化的 MSM 实现
        if not scalars or not points:
            return (0, 0, 1)  # 单位元
        
        result_x, result_y, result_z = 0, 0, 1
        for scalar, point in zip(scalars, points):
            # 简化：直接累加
            if hasattr(point, 'x'):
                result_x = (result_x + scalar * point.x) % zkp_metal.BLS12_381_MODULUS
                result_y = (result_y + scalar * point.y) % zkp_metal.BLS12_381_MODULUS
            else:
                result_x = (result_x + scalar * point[0]) % zkp_metal.BLS12_381_MODULUS
                result_y = (result_y + scalar * point[1]) % zkp_metal.BLS12_381_MODULUS
        
        return (result_x, result_y, result_z)
    
    def _cpu_poly_multiply(self, a: List[int], b: List[int]) -> List[int]:
        """CPU 多项式乘法参考实现"""
        if not a or not b:
            return []
        
        result = [0] * (len(a) + len(b) - 1)
        modulus = zkp_metal.BLS12_381_MODULUS
        
        for i in range(len(a)):
            for j in range(len(b)):
                result[i + j] = (result[i + j] + a[i] * b[j]) % modulus
        
        return result
    
    def _verify_results(self, cpu_result: List[int], gpu_result: List[int], tolerance: float = 1e-10) -> bool:
        """验证 CPU 和 GPU 结果是否一致"""
        if len(cpu_result) != len(gpu_result):
            return False
        
        for a, b in zip(cpu_result, gpu_result):
            if abs(a - b) > tolerance:
                return False
        
        return True
    
    def _verify_points(self, cpu_point: Any, gpu_point: Any, tolerance: float = 1e-10) -> bool:
        """验证椭圆曲线点是否一致"""
        if hasattr(cpu_point, 'x'):
            cpu_coords = (cpu_point.x, cpu_point.y, cpu_point.z)
        else:
            cpu_coords = cpu_point
        
        if hasattr(gpu_point, 'x'):
            gpu_coords = (gpu_point.x, gpu_point.y, gpu_point.z)
        else:
            gpu_coords = gpu_point
        
        for a, b in zip(cpu_coords, gpu_coords):
            if abs(a - b) > tolerance:
                return False
        
        return True
    
    def save_results(self, filename: str):
        """保存测试结果到文件"""
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"📊 结果已保存到 {filename}")

def main():
    """主函数"""
    parser = argparse.ArgumentParser(description="ZKP Metal 性能基准测试")
    parser.add_argument("--ntt-sizes", nargs="+", type=int, 
                       default=[1024, 4096, 16384, 65536],
                       help="NTT 测试大小")
    parser.add_argument("--msm-sizes", nargs="+", type=int,
                       default=[256, 1024, 4096],
                       help="MSM 测试大小")
    parser.add_argument("--poly-sizes", nargs="+", type=int,
                       default=[512, 1024, 2048, 4096],
                       help="多项式乘法测试大小")
    parser.add_argument("--iterations", type=int, default=10,
                       help="每个测试的迭代次数")
    parser.add_argument("--output", type=str, default="benchmark_results.json",
                       help="结果输出文件")
    parser.add_argument("--memory-test", action="store_true",
                       help="运行内存使用测试")
    
    args = parser.parse_args()
    
    print("🚀 ZKP Metal 性能基准测试")
    print("=" * 60)
    
    # 显示系统信息
    if METAL_AVAILABLE:
        zkp_metal.print_system_info()
    else:
        print("❌ Metal 不可用")
        return 1
    
    # 创建基准测试运行器
    runner = BenchmarkRunner()
    
    # 运行测试
    runner.results['ntt'] = runner.benchmark_ntt(args.ntt_sizes, args.iterations)
    runner.results['msm'] = runner.benchmark_msm(args.msm_sizes, args.iterations)
    runner.results['polynomial_multiply'] = runner.benchmark_polynomial_multiply(
        args.poly_sizes, args.iterations)
    
    if args.memory_test:
        runner.results['memory'] = runner.run_memory_benchmark()
    
    # 保存结果
    runner.save_results(args.output)
    
    print("\n✅ 所有测试完成")
    return 0

if __name__ == "__main__":
    sys.exit(main())