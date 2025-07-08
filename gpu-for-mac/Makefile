# GPU for Mac ZKP Makefile

.PHONY: help install test benchmark clean metal

help:
	@echo "GPU for Mac ZKP - 可用命令:"
	@echo ""
	@echo "  install      - 安装依赖"
	@echo "  test         - 运行测试"
	@echo "  benchmark    - 运行基准测试"
	@echo "  verify       - 验证 Metal 着色器"
	@echo "  verify-ntt   - 验证 NTT 着色器"
	@echo "  verify-msm   - 验证 MSM 着色器"
	@echo "  metal        - 编译 Metal 着色器"
	@echo "  clean        - 清理文件"
	@echo "  info         - 系统信息"

install:
	@./install.sh

test:
	@python simple-proof/simple_test.py

benchmark:
	@python benchmarks/comprehensive_benchmark.py --quick

verify:
	@python verify/verify_all.py

verify-ntt:
	@python verify/verify_ntt.py

verify-msm:
	@python verify/verify_msm.py

metal:
	@for metal_file in metal-shaders/*/*.metal; do \
		if [ -f "$$metal_file" ]; then \
			base=$$(basename "$$metal_file" .metal); \
			dir=$$(dirname "$$metal_file"); \
			echo "编译 $$base.metal"; \
			xcrun -sdk macosx metal -c "$$metal_file" -o "$$dir/$$base.air" 2>/dev/null && \
			xcrun -sdk macosx metallib "$$dir/$$base.air" -o "$$dir/$$base.metallib" 2>/dev/null && \
			rm -f "$$dir/$$base.air" || echo "编译失败"; \
		fi \
	done

clean:
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@find . -name "*.air" -delete
	@find . -name "*.metallib" -delete
	@rm -f benchmark_results.json

info:
	@echo "系统: $$(sw_vers -productVersion)"
	@echo "CPU: $$(sysctl -n machdep.cpu.brand_string)"
	@echo "Python: $$(python --version)"
	@python -c "import Metal; print('GPU:', Metal.MTLCreateSystemDefaultDevice().name())" 2>/dev/null || echo "GPU: Metal 不可用"