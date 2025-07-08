#!/usr/bin/env python3

from setuptools import setup, find_packages, Extension
from pybind11.setup_helpers import Pybind11Extension, build_ext
from pybind11 import get_cmake_dir
import pybind11
import platform
import os

# 检查是否在 macOS 上
if platform.system() != 'Darwin':
    raise RuntimeError("此包只支持 macOS 平台")

# 检查 Metal 支持
def check_metal_support():
    try:
        import subprocess
        result = subprocess.run(['metal', '--version'], 
                              capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

if not check_metal_support():
    print("警告: 未检测到 Metal 支持，某些功能可能不可用")

# 扩展模块定义
ext_modules = [
    Pybind11Extension(
        "zkp_metal._core",
        [
            "src/python_bindings.cpp",
            "src/metal_wrapper.mm",  # Objective-C++ 文件
            "src/ntt_wrapper.cpp",
            "src/msm_wrapper.cpp",
        ],
        include_dirs=[
            # pybind11 头文件
            pybind11.get_include(),
            # 本地头文件
            "include",
            # Metal 头文件
            "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/System/Library/Frameworks/Metal.framework/Headers",
        ],
        libraries=["objc"],
        extra_compile_args=[
            "-std=c++17",
            "-O3",
            "-ffast-math",
            "-DWITH_METAL",
        ],
        extra_link_args=[
            "-framework", "Metal",
            "-framework", "Foundation",
            "-framework", "MetalPerformanceShaders",
        ],
        language='c++',
        cxx_std=17,
    ),
]

# 读取 README
def read_readme():
    readme_path = os.path.join(os.path.dirname(__file__), "README.md")
    if os.path.exists(readme_path):
        with open(readme_path, "r", encoding="utf-8") as f:
            return f.read()
    return "ZKP Metal - GPU 加速的零知识证明计算库"

setup(
    name="zkp-metal",
    version="0.1.0",
    author="ZKP Metal Team",
    author_email="zkp-metal@example.com",
    description="GPU 加速的零知识证明计算库 (macOS)",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    url="https://github.com/your-org/zkp-metal",
    packages=find_packages(),
    ext_modules=ext_modules,
    cmdclass={"build_ext": build_ext},
    zip_safe=False,
    python_requires=">=3.8",
    install_requires=[
        "numpy>=1.20.0",
        "pybind11>=2.10.0",
    ],
    extras_require={
        "dev": [
            "pytest>=6.0",
            "pytest-benchmark",
            "black",
            "flake8",
            "mypy",
        ],
        "docs": [
            "sphinx",
            "sphinx-rtd-theme",
            "myst-parser",
        ],
        "test": [
            "pytest>=6.0",
            "pytest-benchmark",
            "hypothesis",
        ],
    },
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Operating System :: MacOS",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: C++",
        "Topic :: Scientific/Engineering :: Mathematics",
        "Topic :: Security :: Cryptography",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    keywords="zkp zero-knowledge-proof gpu metal cryptography",
    project_urls={
        "Bug Reports": "https://github.com/your-org/zkp-metal/issues",
        "Source": "https://github.com/your-org/zkp-metal",
        "Documentation": "https://zkp-metal.readthedocs.io/",
    },
)