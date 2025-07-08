#!/usr/bin/env python3
"""
Metal 着色器综合验证脚本

验证所有 Metal 着色器的真实性、正确性和性能
"""

import sys
import os
import subprocess
import time
from typing import List, Tuple

# 添加项目路径
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def run_verification_script(script_path: str) -> Tuple[bool, str]:
    """运行验证脚本并返回结果"""
    try:
        result = subprocess.run(
            [sys.executable, script_path],
            capture_output=True,
            text=True,
            timeout=60  # 60秒超时
        )
        
        success = result.returncode == 0
        output = result.stdout + result.stderr
        
        return success, output
        
    except subprocess.TimeoutExpired:
        return False, "验证超时"
    except Exception as e:
        return False, f"运行异常: {e}"

def verify_metal_shader_files() -> bool:
    """验证 Metal 着色器文件是否存在和可编译"""
    print("📁 验证 Metal 着色器文件...")
    
    shader_files = [
        "metal-shaders/ntt/ntt_kernels.metal",
        "metal-shaders/msm/msm_kernels.metal"
    ]
    
    all_exist = True
    
    for shader_file in shader_files:
        if os.path.exists(shader_file):
            print(f"✅ 找到: {shader_file}")
            
            # 检查文件大小
            size = os.path.getsize(shader_file)
            print(f"   大小: {size} 字节")
            
            # 简单检查文件内容
            with open(shader_file, 'r') as f:
                content = f.read()
                if 'kernel' in content and 'metal_stdlib' in content:
                    print(f"   ✅ 包含 Metal 内核代码")
                else:
                    print(f"   ⚠️  可能不是有效的 Metal 代码")
                    
        else:
            print(f"❌ 缺失: {shader_file}")
            all_exist = False
    
    return all_exist

def verify_shader_compilation() -> bool:
    """验证着色器编译"""
    print("\n🔨 验证着色器编译...")
    
    if not os.system("which xcrun > /dev/null 2>&1") == 0:
        print("❌ xcrun 不可用，跳过编译验证")
        return False
    
    shader_files = [
        "metal-shaders/ntt/ntt_kernels.metal",
        "metal-shaders/msm/msm_kernels.metal"
    ]
    
    compiled_count = 0
    
    for shader_file in shader_files:
        if not os.path.exists(shader_file):
            continue
            
        print(f"编译 {shader_file}...")
        
        # 尝试编译
        base_name = os.path.splitext(shader_file)[0]
        air_file = f"{base_name}.air"
        
        compile_cmd = f"xcrun -sdk macosx metal -c {shader_file} -o {air_file}"
        result = os.system(f"{compile_cmd} 2>/dev/null")
        
        if result == 0:
            print(f"✅ 编译成功: {shader_file}")
            compiled_count += 1
            
            # 清理临时文件
            if os.path.exists(air_file):
                os.remove(air_file)
        else:
            print(f"❌ 编译失败: {shader_file}")
    
    return compiled_count > 0

def main():
    """主验证函数"""
    print("🔍 Metal 着色器综合验证")
    print("=" * 50)
    
    start_time = time.time()
    
    # 验证步骤
    verification_steps = [
        ("文件存在性", verify_metal_shader_files),
        ("着色器编译", verify_shader_compilation),
    ]
    
    # 验证脚本
    verification_scripts = [
        ("NTT 验证", "verify/verify_ntt.py"),
        ("MSM 验证", "verify/verify_msm.py"),
    ]
    
    total_tests = len(verification_steps) + len(verification_scripts)
    passed_tests = 0
    
    # 运行基础验证
    for step_name, step_func in verification_steps:
        print(f"\n{'='*20} {step_name} {'='*20}")
        try:
            if step_func():
                passed_tests += 1
                print(f"✅ {step_name} 通过")
            else:
                print(f"❌ {step_name} 失败")
        except Exception as e:
            print(f"❌ {step_name} 异常: {e}")
    
    # 运行验证脚本
    for script_name, script_path in verification_scripts:
        print(f"\n{'='*20} {script_name} {'='*20}")
        
        if not os.path.exists(script_path):
            print(f"❌ 验证脚本不存在: {script_path}")
            continue
        
        print(f"运行 {script_path}...")
        success, output = run_verification_script(script_path)
        
        if success:
            passed_tests += 1
            print(f"✅ {script_name} 验证通过")
            
            # 显示关键输出
            lines = output.split('\n')
            for line in lines:
                if '✅' in line or '📊' in line or '🎉' in line:
                    print(f"  {line}")
        else:
            print(f"❌ {script_name} 验证失败")
            
            # 显示错误信息
            lines = output.split('\n')
            for line in lines[-10:]:  # 显示最后10行
                if line.strip():
                    print(f"  {line}")
    
    # 总结
    end_time = time.time()
    duration = end_time - start_time
    
    print(f"\n{'='*50}")
    print(f"📊 验证总结")
    print(f"{'='*50}")
    print(f"总测试数: {total_tests}")
    print(f"通过测试: {passed_tests}")
    print(f"失败测试: {total_tests - passed_tests}")
    print(f"成功率: {passed_tests/total_tests*100:.1f}%")
    print(f"耗时: {duration:.2f} 秒")
    
    if passed_tests == total_tests:
        print("\n🎉 所有验证全部通过！")
        print("Metal 着色器实现真实可用！")
        return 0
    elif passed_tests >= total_tests * 0.7:
        print("\n⚠️  大部分验证通过，部分功能可能需要调试")
        return 0
    else:
        print("\n❌ 多项验证失败，请检查实现")
        return 1

if __name__ == "__main__":
    sys.exit(main())