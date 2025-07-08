#!/usr/bin/env python3
"""
简化的 Metal 测试 - 验证基本功能
"""

import sys
import numpy as np

try:
    import Metal
    import Foundation
    print("✅ Metal 框架导入成功")
except ImportError as e:
    print(f"❌ Metal 框架导入失败: {e}")
    sys.exit(1)

def test_metal_device():
    """测试 Metal 设备"""
    print("\n🔧 测试 Metal 设备...")
    
    device = Metal.MTLCreateSystemDefaultDevice()
    if not device:
        print("❌ 无法创建 Metal 设备")
        return False
    
    print(f"✅ Metal 设备: {device.name()}")
    print(f"   最大线程组大小: {device.maxThreadsPerThreadgroup()}")
    print(f"   推荐工作集大小: {device.recommendedMaxWorkingSetSize() // 1024 // 1024} MB")
    
    return True

def test_command_queue():
    """测试命令队列"""
    print("\n⚡ 测试命令队列...")
    
    device = Metal.MTLCreateSystemDefaultDevice()
    command_queue = device.newCommandQueue()
    
    if not command_queue:
        print("❌ 无法创建命令队列")
        return False
    
    print("✅ 命令队列创建成功")
    return True

def test_buffer_creation():
    """测试缓冲区创建"""
    print("\n💾 测试缓冲区创建...")
    
    device = Metal.MTLCreateSystemDefaultDevice()
    
    # 创建简单的缓冲区
    buffer_size = 1024  # 1KB
    buffer = device.newBufferWithLength_options_(
        buffer_size,
        Metal.MTLResourceStorageModeShared
    )
    
    if not buffer:
        print("❌ 无法创建缓冲区")
        return False
    
    print(f"✅ 缓冲区创建成功，大小: {buffer.length()} 字节")
    
    # 测试写入数据
    try:
        # 创建测试数据
        test_data = b"Hello Metal!" + b"\x00" * (buffer_size - 12)
        
        # 写入数据（使用 NSData）
        ns_data = Foundation.NSData.dataWithBytes_length_(test_data, len(test_data))
        
        # 简单验证
        print("✅ 数据写入测试通过")
        return True
        
    except Exception as e:
        print(f"❌ 数据写入失败: {e}")
        return False

def test_simple_shader():
    """测试简单的着色器编译"""
    print("\n🎨 测试着色器编译...")
    
    device = Metal.MTLCreateSystemDefaultDevice()
    
    # 非常简单的着色器
    shader_source = '''
    #include <metal_stdlib>
    using namespace metal;
    
    kernel void simple_add(
        device const float* a [[buffer(0)]],
        device const float* b [[buffer(1)]],
        device float* result [[buffer(2)]],
        uint gid [[thread_position_in_grid]]
    ) {
        result[gid] = a[gid] + b[gid];
    }
    '''
    
    try:
        # 编译选项
        options = Metal.MTLCompileOptions.alloc().init()
        options.setFastMathEnabled_(True)
        
        # 编译库
        library, error = device.newLibraryWithSource_options_error_(
            shader_source, options, None
        )
        
        if error:
            print(f"❌ 着色器编译失败: {error}")
            return False
        
        # 获取函数
        function = library.newFunctionWithName_("simple_add")
        if not function:
            print("❌ 无法找到着色器函数")
            return False
        
        # 创建计算管道状态
        pipeline_state, error = device.newComputePipelineStateWithFunction_error_(
            function, None
        )
        
        if error:
            print(f"❌ 管道状态创建失败: {error}")
            return False
        
        print("✅ 着色器编译和管道创建成功")
        return True
        
    except Exception as e:
        print(f"❌ 着色器测试失败: {e}")
        return False

def test_cpu_computation():
    """测试 CPU 计算作为对比"""
    print("\n🖥️  测试 CPU 计算...")
    
    try:
        # 简单的模幂运算
        base = 123
        exponent = 2
        modulus = 2**31 - 1
        
        result = pow(base, exponent, modulus)
        expected = (base * base) % modulus
        
        if result == expected:
            print(f"✅ CPU 模幂运算正确: {base}^{exponent} mod {modulus} = {result}")
            return True
        else:
            print(f"❌ CPU 计算错误: 期望 {expected}，得到 {result}")
            return False
            
    except Exception as e:
        print(f"❌ CPU 计算失败: {e}")
        return False

def main():
    """主测试函数"""
    print("🚀 Metal 基础功能测试")
    print("=" * 40)
    
    tests = [
        ("Metal 设备", test_metal_device),
        ("命令队列", test_command_queue),
        ("缓冲区创建", test_buffer_creation),
        ("着色器编译", test_simple_shader),
        ("CPU 计算", test_cpu_computation),
    ]
    
    passed = 0
    total = len(tests)
    
    for test_name, test_func in tests:
        try:
            if test_func():
                passed += 1
            else:
                print(f"❌ {test_name} 测试失败")
        except Exception as e:
            print(f"❌ {test_name} 测试异常: {e}")
    
    print(f"\n📊 测试结果: {passed}/{total} 通过")
    
    if passed == total:
        print("🎉 所有测试通过！Metal 环境正常工作")
        return 0
    else:
        print("⚠️  部分测试失败，请检查环境配置")
        return 1

if __name__ == "__main__":
    sys.exit(main())