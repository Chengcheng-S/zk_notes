# 零知识证明学习笔记

这是一个全面的零知识证明技术学习笔记库，涵盖了从基础理论到实际应用的各个方面。

## 📚 目录结构

### 🔬 基础理论
- **[基础数学](protocol/basic-math/)** - 零知识证明的数学基础
  - [数学基础](protocol/basic-math/math.md) - 群论、椭圆曲线、多项式
  - [FFT & 拉格朗日插值](protocol/basic-math/FFT&&%20Lagrange%20Interpolation.md)
  - [格算法](protocol/basic-math/Lattice%20算法.md)
  - [Pedersen 承诺](protocol/basic-math/Pedersen%20Commitment.md)
  - [数字签名](protocol/basic-math/signature.md)

### 🏗️ 协议与算法

#### SNARK 相关协议
- **[电路系统](protocol/snark-relation/)**
  - [电路基础](protocol/snark-relation/Circuits.md)
  - [Fiat-Shamir 变换](protocol/snark-relation/Fiat-Shamir.md)
  
- **[具体协议实现](protocol/snark-relation/protocol/)**
  - [Groth16](protocol/snark-relation/protocol/groth16/) - 最流行的 zk-SNARK
  - [PLONK](protocol/snark-relation/protocol/plonk/) - 通用可信设置
  - [Bulletproofs](protocol/snark-relation/protocol/bulletproofs/) - 无可信设置
  - [Spartan](protocol/snark-relation/protocol/spartan/) - 基于 Sumcheck

#### STARK 相关协议
- **[STARK 系统](protocol/stark-relation/)**
  - [zk-STARK](protocol/stark-relation/zk-stark.md) - 透明零知识证明
  - [STARK 中的多项式](protocol/stark-relation/polynomial%20in%20stark%20.md)

#### 🚀 新兴技术与协议
- **[前沿协议](protocol/emerging-tech/)**
  - [Folding Schemes](protocol/emerging-tech/folding-schemes.md) - Nova, SuperNova, HyperNova
  - [Lookup Arguments](protocol/emerging-tech/lookup-arguments.md) - Plookup, Lasso, cq
  - [Binius](protocol/emerging-tech/binius.md) - 二进制域零知识证明
  - [高级协议](protocol/emerging-tech/advanced-protocols.md) - 最新协议发展 🆕
  - [ZKML & AI](protocol/emerging-tech/zkml-and-ai.md) - 零知识机器学习 🆕

### 🛠️ 工具与实现

#### 电路工具
- **[Circom 工具链](circuits-tools/)**
  - [Circom 基础](circuits-tools/circom.md)
  
- **[各种证明库](circuits-tools/)**
  - [gnark](circuits-tools/gnark/) - Go 语言 ZK 库
  - [Halo2](circuits-tools/halo2/) - Zcash 的递归证明系统
  - [Lambdaworks](circuits-tools/lambdaworks/) - Rust ZK 库
  - [Plonky3](circuits-tools/plonky3/) - 高性能 STARK 实现

#### zkVM 与 zkEVM
- **[虚拟机实现](zkvm%20&&%20zkevm/)**
  - [SP1](zkvm%20&&%20zkevm/sp1/) - Succinct 的 zkVM
  - [Risc0](zkvm%20&&%20zkevm/risc0/) - RISC-V 零知识虚拟机
  - [Jolt](zkvm%20&&%20zkevm/jolt/) - 基于查找表的 zkVM
  - [Nexus](zkvm%20&&%20zkevm/nexus/) - 递归零知识虚拟机
  - [Miden VM](zkvm%20&&%20zkevm/miden-vm/) - Polygon 的 STARK 虚拟机
  - [zkEVM](zkvm%20&&%20zkevm/zkevm/) - 以太坊虚拟机的零知识实现
  - [总结对比](zkvm%20&&%20zkevm/总结.md) - 各 zkVM 系统对比

### 🏢 实际项目

#### Layer 2 解决方案
- **[zk-Rollup 项目](zk-roullp/)**
  - [zkSync](zk-roullp/zk-sync/) - Matter Labs 的 L2 解决方案
  - [StarkNet](zk-roullp/starknet/) - StarkWare 的 L2 网络
  - [Sovereign](zk-roullp/Sovereign/) - 模块化区块链

#### 隐私应用
- **[隐私项目](projects/)**
  - [Tornado Cash](projects/tornado%20cash/) - 以太坊混币器

### 🔐 签名算法
- **[数字签名](Signature%20Algorithm/)**
  - [ECDSA](Signature%20Algorithm/ECDSA.md)
  - [Ed25519 & sr25519](Signature%20Algorithm/Ed25519%20&&%20sr25519.md)
  - [Schnorr 签名](Signature%20Algorithm/Schnorr.md)
  - [BLS 签名](Signature%20Algorithm/BLS-381%20&&%20bls377.md)
  - [椭圆曲线](Signature%20Algorithm/Secp256k1%20&&%20secp256r1.md)

### 📊 性能优化与实践 🆕

#### 性能分析
- **[性能优化](performance/)**
  - [优化技术](performance/optimization-techniques.md) - 全面的性能优化指南
  - [基准测试](performance/benchmarks-and-comparison.md) - 各系统性能对比

#### 实践指南
- **[实用指南](practical-guides/)**
  - [开发工作流](practical-guides/development-workflow.md) - 完整开发流程
  - [安全最佳实践](practical-guides/security-best-practices.md) - 安全开发指南

### 🧮 数学工具
- **[Sage 数学](sage-math/)**
  - [Sage 使用指南](sage-math/sage.md)

### 💭 个人思考
- **[协议思考](protocol/)**
  - [个人见解](protocol/Personally-think.md)
  - [其他技术](protocol/another-things.md) - R1CS vs Plonkish 等
  - [硬件相关](protocol/hardware.md)

## 🎯 学习路径建议

### 初学者路径
1. **基础数学** → [数学基础](protocol/basic-math/math.md)
2. **电路概念** → [电路基础](protocol/snark-relation/Circuits.md)
3. **第一个协议** → [Groth16](protocol/snark-relation/protocol/groth16/groth16.md)
4. **实践操作** → [开发工作流](practical-guides/development-workflow.md)

### 进阶路径
1. **深入协议** → [PLONK](protocol/snark-relation/protocol/plonk/plonk.md) + [STARK](protocol/stark-relation/zk-stark.md)
2. **新兴技术** → [Folding Schemes](protocol/emerging-tech/folding-schemes.md)
3. **性能优化** → [优化技术](performance/optimization-techniques.md)
4. **安全实践** → [安全最佳实践](practical-guides/security-best-practices.md)

### 应用开发路径
1. **选择工具** → [工具对比](circuits-tools/) + [性能基准](performance/benchmarks-and-comparison.md)
2. **zkVM 开发** → [SP1](zkvm%20&&%20zkevm/sp1/) 或 [Jolt](zkvm%20&&%20zkevm/jolt/)
3. **项目实践** → 参考 [实际项目](projects/)
4. **ZKML 探索** → [ZKML & AI](protocol/emerging-tech/zkml-and-ai.md)

## 🔄 最近更新

### 2024年新增内容 🆕
- **高级协议**: SuperNova, HyperNova, Sangria 等最新发展
- **ZKML 技术**: 零知识机器学习的完整指南
- **性能优化**: 电路、算法、系统级优化技术
- **基准测试**: 各证明系统的详细性能对比
- **开发实践**: 从环境搭建到生产部署的完整流程
- **安全指南**: 密码学安全、电路安全、协议安全最佳实践

## 📖 如何使用这个笔记库

### 按技术栈学习
- **理论研究者**: 重点关注 `protocol/` 目录
- **工程开发者**: 重点关注 `circuits-tools/` 和 `practical-guides/`
- **应用开发者**: 重点关注 `zkvm && zkevm/` 和 `projects/`
- **性能优化**: 重点关注 `performance/` 目录

### 按应用场景学习
- **DeFi 开发**: Tornado Cash → zkSync → 性能优化
- **隐私计算**: Bulletproofs → STARK → Binius
- **Layer 2**: PLONK → zkEVM → 各 L2 项目分析
- **机器学习**: ZKML → 性能优化 → 安全实践

## 🤝 贡献指南

这个笔记库持续更新中，欢迎：
- 指出错误和不准确的地方
- 补充最新的技术发展
- 分享实践经验和优化技巧
- 添加更多实际应用案例

## 📞 联系方式

如有问题或建议，欢迎通过以下方式联系：
- 创建 Issue 讨论技术问题
- 提交 PR 贡献内容
- 分享你的学习心得

---

*持续学习，持续更新。零知识证明技术日新月异，让我们一起探索这个激动人心的领域！* 🚀