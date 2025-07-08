"""
ZKP Metal - GPU 加速的零知识证明计算库

这个库提供了在 macOS 平台上使用 Metal 进行 GPU 加速的 ZKP 计算功能。

主要功能:
- 数论变换 (NTT) GPU 加速
- 多标量乘法 (MSM) 优化
- 多项式运算加速
- 椭圆曲线运算

示例用法:
    >>> import zkp_metal
    >>> engine = zkp_metal.MetalEngine()
    >>> result = engine.ntt([1, 2, 3, 4, 0, 0, 0, 0])
    >>> print(result)
"""

__version__ = "0.1.0"
__author__ = "ZKP Metal Team"
__email__ = "zkp-metal@example.com"

# 导入核心功能
try:
    from ._core import (
        MetalEngine,
        EllipticCurvePoint,
        is_metal_available,
        get_metal_device_info,
    )
    
    # 高级 API
    from .api import (
        ntt,
        intt,
        polynomial_multiply,
        msm,
        batch_ntt,
    )
    
    # 工具函数
    from .utils import (
        generate_random_field_elements,
        generate_random_points,
        benchmark_operations,
        validate_ntt_result,
    )
    
    # 常量
    from .constants import (
        BLS12_381_MODULUS,
        BLS12_381_ROOT_OF_UNITY,
        SUPPORTED_NTT_SIZES,
    )
    
    _METAL_AVAILABLE = True
    
except ImportError as e:
    print(f"警告: 无法导入 Metal 核心模块: {e}")
    print("某些功能可能不可用。请检查 Metal 支持和编译配置。")
    _METAL_AVAILABLE = False
    
    # 提供备用实现
    class MetalEngine:
        def __init__(self):
            raise RuntimeError("Metal 不可用，请检查系统配置")
    
    def is_metal_available():
        return False

# 公开的 API
__all__ = [
    # 核心类
    'MetalEngine',
    'EllipticCurvePoint',
    
    # 高级函数
    'ntt',
    'intt', 
    'polynomial_multiply',
    'msm',
    'batch_ntt',
    
    # 工具函数
    'generate_random_field_elements',
    'generate_random_points',
    'benchmark_operations',
    'validate_ntt_result',
    'is_metal_available',
    'get_metal_device_info',
    
    # 常量
    'BLS12_381_MODULUS',
    'BLS12_381_ROOT_OF_UNITY',
    'SUPPORTED_NTT_SIZES',
]

def get_version():
    """获取版本信息"""
    return __version__

def get_build_info():
    """获取构建信息"""
    import platform
    import sys
    
    info = {
        'version': __version__,
        'python_version': sys.version,
        'platform': platform.platform(),
        'metal_available': _METAL_AVAILABLE,
    }
    
    if _METAL_AVAILABLE:
        try:
            device_info = get_metal_device_info()
            info.update(device_info)
        except:
            pass
    
    return info

def print_system_info():
    """打印系统信息"""
    info = get_build_info()
    
    print("🚀 ZKP Metal 系统信息")
    print("=" * 40)
    print(f"版本: {info['version']}")
    print(f"Python: {info['python_version']}")
    print(f"平台: {info['platform']}")
    print(f"Metal 可用: {'✅' if info['metal_available'] else '❌'}")
    
    if info['metal_available'] and 'device_name' in info:
        print(f"GPU 设备: {info['device_name']}")
        print(f"最大线程组: {info.get('max_threadgroup_size', 'N/A')}")
        print(f"最大缓冲区: {info.get('max_buffer_length', 'N/A')} bytes")

# 模块级别的便捷函数
def quick_ntt(data):
    """快速 NTT 计算的便捷函数"""
    if not _METAL_AVAILABLE:
        raise RuntimeError("Metal 不可用")
    
    engine = MetalEngine()
    return engine.ntt(data)

def quick_polynomial_multiply(a, b):
    """快速多项式乘法的便捷函数"""
    if not _METAL_AVAILABLE:
        raise RuntimeError("Metal 不可用")
    
    engine = MetalEngine()
    return engine.polynomial_multiply(a, b)

# 初始化检查
def _check_environment():
    """检查运行环境"""
    import platform
    
    if platform.system() != 'Darwin':
        print("⚠️  警告: ZKP Metal 只在 macOS 上受支持")
        return False
    
    if not _METAL_AVAILABLE:
        print("⚠️  警告: Metal 功能不可用")
        return False
    
    return True

# 执行环境检查
_ENVIRONMENT_OK = _check_environment()

if _ENVIRONMENT_OK and _METAL_AVAILABLE:
    print("✅ ZKP Metal 初始化成功")
else:
    print("⚠️  ZKP Metal 初始化时遇到问题")