#!/bin/bash
# GPU for Mac ZKP 计算库自动安装脚本

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# 检查系统要求
check_system_requirements() {
    print_info "检查系统要求..."
    
    # 检查操作系统
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_error "此项目仅支持 macOS 系统"
        exit 1
    fi
    
    # 检查 macOS 版本
    macos_version=$(sw_vers -productVersion)
    print_info "macOS 版本: $macos_version"
    
    # 建议 macOS 12.0+
    if [[ $(echo "$macos_version 12.0" | tr " " "\n" | sort -V | head -n1) != "12.0" ]]; then
        print_warning "建议使用 macOS 12.0 或更高版本以获得最佳性能"
    fi
    
    # 检查 Xcode Command Line Tools
    if ! xcode-select -p &> /dev/null; then
        print_warning "未检测到 Xcode Command Line Tools"
        print_info "正在安装 Xcode Command Line Tools..."
        xcode-select --install
        print_info "请完成 Xcode Command Line Tools 安装后重新运行此脚本"
        exit 1
    fi
    
    # 检查 Metal 支持
    if ! system_profiler SPDisplaysDataType | grep -q "Metal"; then
        print_warning "系统可能不支持 Metal，GPU 加速功能可能不可用"
    fi
    
    print_success "系统要求检查完成"
}

# 检查和安装 Python
check_python() {
    print_info "检查 Python 环境..."
    
    # 检查 Python 版本
    if command -v python3 &> /dev/null; then
        python_version=$(python3 --version | cut -d' ' -f2)
        print_info "Python 版本: $python_version"
        
        # 检查版本是否 >= 3.8
        if [[ $(echo "$python_version 3.8.0" | tr " " "\n" | sort -V | head -n1) != "3.8.0" ]]; then
            print_error "需要 Python 3.8 或更高版本，当前版本: $python_version"
            print_info "请安装更新的 Python 版本"
            exit 1
        fi
    else
        print_error "未找到 Python 3"
        print_info "请安装 Python 3.8 或更高版本"
        print_info "推荐使用 Homebrew: brew install python@3.11"
        exit 1
    fi
    
    # 检查 pip
    if ! command -v pip3 &> /dev/null; then
        print_error "未找到 pip3"
        print_info "请安装 pip3"
        exit 1
    fi
    
    print_success "Python 环境检查完成"
}

# 创建虚拟环境
create_virtual_environment() {
    print_info "创建 Python 虚拟环境..."
    
    if [[ ! -d "venv" ]]; then
        python3 -m venv venv
        print_success "虚拟环境创建完成"
    else
        print_info "虚拟环境已存在"
    fi
    
    # 激活虚拟环境
    source venv/bin/activate
    
    # 升级 pip
    pip install --upgrade pip
    
    print_success "虚拟环境准备完成"
}

# 安装依赖
install_dependencies() {
    print_info "安装项目依赖..."
    
    # 确保在虚拟环境中
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        print_warning "未在虚拟环境中，正在激活..."
        source venv/bin/activate
    fi
    
    # 安装基础依赖
    print_info "安装基础依赖..."
    pip install -r requirements.txt
    
    # 安装开发依赖（可选）
    if [[ "$1" == "--dev" ]]; then
        print_info "安装开发依赖..."
        pip install pytest pytest-benchmark black flake8 mypy jupyter matplotlib seaborn
    fi
    
    print_success "依赖安装完成"
}

# 编译 Metal 着色器
compile_metal_shaders() {
    print_info "编译 Metal 着色器..."
    
    # 检查 Metal 编译器
    if ! command -v xcrun &> /dev/null; then
        print_error "未找到 xcrun，请确保已安装 Xcode Command Line Tools"
        exit 1
    fi
    
    # 编译着色器
    shader_dirs=("metal-shaders/ntt" "metal-shaders/msm" "metal-shaders/field")
    
    for dir in "${shader_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            print_info "编译 $dir 中的着色器..."
            
            for metal_file in "$dir"/*.metal; do
                if [[ -f "$metal_file" ]]; then
                    filename=$(basename "$metal_file" .metal)
                    output_file="$dir/${filename}.metallib"
                    
                    if xcrun -sdk macosx metal -c "$metal_file" -o "${metal_file%.metal}.air" 2>/dev/null; then
                        if xcrun -sdk macosx metallib "${metal_file%.metal}.air" -o "$output_file" 2>/dev/null; then
                            print_success "编译完成: $output_file"
                            # 清理临时文件
                            rm -f "${metal_file%.metal}.air"
                        else
                            print_warning "链接失败: $metal_file"
                        fi
                    else
                        print_warning "编译失败: $metal_file"
                    fi
                fi
            done
        fi
    done
    
    print_success "Metal 着色器编译完成"
}

# 运行测试
run_tests() {
    print_info "运行基础测试..."
    
    # 确保在虚拟环境中
    if [[ "$VIRTUAL_ENV" == "" ]]; then
        source venv/bin/activate
    fi
    
    # 测试 Metal 可用性
    python3 -c "
import sys
try:
    import Metal
    device = Metal.MTLCreateSystemDefaultDevice()
    if device:
        print('✅ Metal 设备可用:', device.name())
    else:
        print('❌ Metal 设备不可用')
        sys.exit(1)
except ImportError:
    print('❌ 无法导入 Metal 框架')
    sys.exit(1)
"
    
    if [[ $? -eq 0 ]]; then
        print_success "Metal 测试通过"
    else
        print_error "Metal 测试失败"
        exit 1
    fi
    
    # 运行简单示例
    if [[ -f "simple-proof/simple_zkp_example.py" ]]; then
        print_info "运行简单 ZKP 示例..."
        python3 simple-proof/simple_zkp_example.py
        
        if [[ $? -eq 0 ]]; then
            print_success "示例运行成功"
        else
            print_warning "示例运行失败，但安装可能仍然成功"
        fi
    fi
}

# 显示使用说明
show_usage_instructions() {
    print_success "安装完成！"
    echo
    print_info "使用说明:"
    echo "1. 激活虚拟环境:"
    echo "   source venv/bin/activate"
    echo
    echo "2. 运行基准测试:"
    echo "   python3 benchmarks/comprehensive_benchmark.py"
    echo
    echo "3. 运行简单示例:"
    echo "   python3 simple-proof/simple_zkp_example.py"
    echo
    echo "4. 查看文档:"
    echo "   open docs/getting-started.md"
    echo
    print_info "项目结构:"
    echo "├── docs/                 # 文档"
    echo "├── metal-shaders/        # Metal 着色器"
    echo "├── benchmarks/           # 性能测试"
    echo "├── simple-proof/         # 简单示例"
    echo "├── setup/                # 安装配置"
    echo "└── venv/                 # Python 虚拟环境"
    echo
}

# 主函数
main() {
    echo "🚀 GPU for Mac ZKP 计算库安装程序"
    echo "=================================="
    echo
    
    # 解析命令行参数
    dev_mode=false
    skip_tests=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dev)
                dev_mode=true
                shift
                ;;
            --skip-tests)
                skip_tests=true
                shift
                ;;
            --help|-h)
                echo "用法: $0 [选项]"
                echo "选项:"
                echo "  --dev         安装开发依赖"
                echo "  --skip-tests  跳过测试"
                echo "  --help        显示此帮助信息"
                exit 0
                ;;
            *)
                print_error "未知选项: $1"
                exit 1
                ;;
        esac
    done
    
    # 执行安装步骤
    check_system_requirements
    check_python
    create_virtual_environment
    
    if [[ "$dev_mode" == true ]]; then
        install_dependencies --dev
    else
        install_dependencies
    fi
    
    compile_metal_shaders
    
    if [[ "$skip_tests" != true ]]; then
        run_tests
    fi
    
    show_usage_instructions
}

# 运行主函数
main "$@"