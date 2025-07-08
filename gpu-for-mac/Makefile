# GPU for Mac ZKP 计算库 Makefile

.PHONY: help install install-dev test benchmark clean format lint docs

# 默认目标
help:
	@echo "GPU for Mac ZKP 计算库 - 可用命令:"
	@echo ""
	@echo "  install      - 安装项目和依赖"
	@echo "  install-dev  - 安装项目和开发依赖"
	@echo "  test         - 运行测试"
	@echo "  benchmark    - 运行基准测试"
	@echo "  clean        - 清理构建文件"
	@echo "  format       - 格式化代码"
	@echo "  lint         - 代码检查"
	@echo "  docs         - 生成文档"
	@echo "  metal        - 编译 Metal 着色器"
	@echo "  demo         - 运行演示"

# 安装
install:
	@echo "🔧 安装项目..."
	./install.sh

install-dev:
	@echo "🔧 安装项目 (开发模式)..."
	./install.sh --dev

# 测试
test:
	@echo "🧪 运行测试..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && python -m pytest tests/ -v; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

# 基准测试
benchmark:
	@echo "📊 运行基准测试..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && python benchmarks/comprehensive_benchmark.py; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

benchmark-quick:
	@echo "📊 运行快速基准测试..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && python benchmarks/comprehensive_benchmark.py --quick; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

# 演示
demo:
	@echo "🎯 运行简单 ZKP 演示..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && python simple-proof/simple_zkp_example.py; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

# Metal 着色器编译
metal:
	@echo "⚡ 编译 Metal 着色器..."
	@for dir in metal-shaders/*/; do \
		if [ -d "$$dir" ]; then \
			echo "编译 $$dir"; \
			for metal_file in "$$dir"*.metal; do \
				if [ -f "$$metal_file" ]; then \
					base_name=$$(basename "$$metal_file" .metal); \
					echo "  编译 $$base_name.metal"; \
					xcrun -sdk macosx metal -c "$$metal_file" -o "$$dir$$base_name.air" 2>/dev/null || echo "    编译失败"; \
					xcrun -sdk macosx metallib "$$dir$$base_name.air" -o "$$dir$$base_name.metallib" 2>/dev/null || echo "    链接失败"; \
					rm -f "$$dir$$base_name.air"; \
				fi \
			done \
		fi \
	done

# 代码格式化
format:
	@echo "🎨 格式化代码..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && \
		black . --exclude venv && \
		echo "✅ 代码格式化完成"; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install-dev"; \
	fi

# 代码检查
lint:
	@echo "🔍 代码检查..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && \
		flake8 . --exclude venv --max-line-length=88 && \
		mypy . --exclude venv --ignore-missing-imports && \
		echo "✅ 代码检查通过"; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install-dev"; \
	fi

# 文档生成
docs:
	@echo "📚 生成文档..."
	@echo "文档位于 docs/ 目录"
	@echo "主要文档文件:"
	@echo "  - docs/getting-started.md"
	@echo "  - docs/metal-programming.md"
	@echo "  - docs/optimization-tips.md"
	@echo "  - docs/troubleshooting.md"

# 清理
clean:
	@echo "🧹 清理构建文件..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type f -name "*.air" -delete
	find . -type f -name "*.metallib" -delete
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info/
	rm -f benchmark_results.json
	@echo "✅ 清理完成"

clean-all: clean
	@echo "🧹 完全清理..."
	rm -rf venv/
	@echo "✅ 完全清理完成"

# 系统信息
info:
	@echo "🖥️  系统信息:"
	@echo "操作系统: $$(uname -s)"
	@echo "架构: $$(uname -m)"
	@echo "macOS 版本: $$(sw_vers -productVersion)"
	@echo "CPU: $$(sysctl -n machdep.cpu.brand_string)"
	@echo "内存: $$(echo $$(($$(sysctl -n hw.memsize) / 1024 / 1024 / 1024))) GB"
	@if command -v python3 >/dev/null 2>&1; then \
		echo "Python 版本: $$(python3 --version)"; \
	fi
	@if [ -d "venv" ]; then \
		echo "虚拟环境: ✅ 已创建"; \
	else \
		echo "虚拟环境: ❌ 未创建"; \
	fi

# 性能分析
profile:
	@echo "📈 运行性能分析..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && \
		python -m cProfile -o profile_results.prof benchmarks/comprehensive_benchmark.py --quick && \
		echo "性能分析结果保存到 profile_results.prof"; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

# 检查依赖
check-deps:
	@echo "🔍 检查依赖..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && \
		pip list --outdated; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi

# 更新依赖
update-deps:
	@echo "⬆️  更新依赖..."
	@if [ -d "venv" ]; then \
		source venv/bin/activate && \
		pip install --upgrade -r requirements.txt; \
	else \
		echo "❌ 虚拟环境不存在，请先运行 make install"; \
	fi