#!/usr/bin/env python3
"""
GPU for Mac ZKP 计算库安装脚本
"""

from setuptools import setup, find_packages
import os
import sys

# 检查是否在 macOS 上
if sys.platform != 'darwin':
    print("❌ 错误: 此库仅支持 macOS 平台")
    sys.exit(1)

# 读取 README
def read_readme():
    readme_path = os.path.join(os.path.dirname(__file__), 'Readme.md')
    if os.path.exists(readme_path):
        with open(readme_path, 'r', encoding='utf-8') as f:
            return f.read()
    return "GPU accelerated ZKP computations for Mac"

# 读取版本信息
def get_version():
    version_file = os.path.join(os.path.dirname(__file__), 'VERSION')
    if os.path.exists(version_file):
        with open(version_file, 'r') as f:
            return f.read().strip()
    return "0.1.0"

# 依赖包
install_requires = [
    'numpy>=1.20.0',
    'scipy>=1.7.0',
    'pyobjc-framework-Metal>=8.0',
    'pyobjc-framework-MetalKit>=8.0',
    'pyobjc-framework-Quartz>=8.0',
    'pyobjc-core>=8.0',
]

# 开发依赖
dev_requires = [
    'pytest>=6.0',
    'pytest-benchmark>=3.4.0',
    'black>=21.0',
    'flake8>=3.9.0',
    'mypy>=0.910',
    'jupyter>=1.0.0',
    'matplotlib>=3.3.0',
    'seaborn>=0.11.0',
]

# 文档依赖
docs_requires = [
    'sphinx>=4.0.0',
    'sphinx-rtd-theme>=0.5.0',
    'myst-parser>=0.15.0',
]

setup(
    name="gpu-for-mac-zkp",
    version=get_version(),
    author="GPU for Mac ZKP Team",
    author_email="contact@gpu-for-mac-zkp.dev",
    description="GPU accelerated Zero-Knowledge Proof computations for Mac",
    long_description=read_readme(),
    long_description_content_type="text/markdown",
    url="https://github.com/gpu-for-mac/zkp-computations",
    packages=find_packages(exclude=['tests', 'benchmarks', 'examples']),
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
        "Topic :: Scientific/Engineering :: Mathematics",
        "Topic :: Security :: Cryptography",
        "Topic :: Software Development :: Libraries :: Python Modules",
    ],
    python_requires=">=3.8",
    install_requires=install_requires,
    extras_require={
        'dev': dev_requires,
        'docs': docs_requires,
        'all': dev_requires + docs_requires,
    },
    entry_points={
        'console_scripts': [
            'zkp-benchmark=benchmarks.comprehensive_benchmark:main',
            'zkp-simple-proof=simple_proof.simple_zkp_example:main',
        ],
    },
    include_package_data=True,
    package_data={
        'gpu_for_mac_zkp': [
            'metal-shaders/**/*.metal',
            'metal-shaders/**/*.h',
        ],
    },
    zip_safe=False,
    keywords="gpu metal macos zkp zero-knowledge-proof cryptography",
    project_urls={
        "Bug Reports": "https://github.com/gpu-for-mac/zkp-computations/issues",
        "Source": "https://github.com/gpu-for-mac/zkp-computations",
        "Documentation": "https://gpu-for-mac-zkp.readthedocs.io/",
    },
)