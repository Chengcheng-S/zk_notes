#!/bin/bash
# GPU for Mac ZKP 安装脚本

set -e

# 颜色输出
info() { echo -e "\033[0;34mℹ️  $1\033[0m"; }
success() { echo -e "\033[0;32m✅ $1\033[0m"; }
warning() { echo -e "\033[1;33m⚠️  $1\033[0m"; }
error() { echo -e "\033[0;31m❌ $1\033[0m"; }

echo "🚀 GPU for Mac ZKP 安装"
echo "======================"

# 检查 macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    error "仅支持 macOS"
    exit 1
fi

info "macOS $(sw_vers -productVersion)"
info "Python $(python --version 2>&1 | cut -d' ' -f2)"

# 安装依赖
info "安装依赖..."
pip install numpy scipy pyobjc-framework-Metal pyobjc-framework-MetalKit pyobjc-core

# 验证 Metal
info "验证 Metal..."
python -c "
import Metal
device = Metal.MTLCreateSystemDefaultDevice()
if device:
    print('✅ Metal 设备:', device.name())
else:
    print('❌ Metal 不可用')
    exit(1)
" || { error "Metal 验证失败"; exit 1; }

# 编译着色器
info "编译着色器..."
if command -v xcrun >/dev/null; then
    for metal_file in metal-shaders/*/*.metal; do
        if [[ -f "$metal_file" ]]; then
            base=$(basename "$metal_file" .metal)
            dir=$(dirname "$metal_file")
            if xcrun -sdk macosx metal -c "$metal_file" -o "$dir/$base.air" 2>/dev/null && \
               xcrun -sdk macosx metallib "$dir/$base.air" -o "$dir/$base.metallib" 2>/dev/null; then
                rm -f "$dir/$base.air"
                success "编译: $base.metallib"
            else
                warning "编译失败: $base"
            fi
        fi
    done
fi

# 运行测试
info "运行测试..."
python simple-proof/simple_test.py

success "安装完成！"
echo
echo "使用方法:"
echo "  python simple-proof/simple_test.py              # 基础测试"
echo "  python benchmarks/comprehensive_benchmark.py    # 性能测试"
echo "  make help                                        # 查看更多命令"