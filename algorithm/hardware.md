## Zk硬件的一些研究

硬件加速被定义为使用优化或创建专用计算机组件来提高特定操作的性能和效率。

* FPGAs：field programmable gate arrays
* GPU：graphics processing uint
* ASICs：application-specific integrated circuits

硬件加速项目的限制因素是内存容量、内存访问速度、数据传输速度和算术单元速度。在同时使用NTT和MSM的证明系统中大部分时间都花费在了MSM上，MSM 可以在**多个线程**上执行，从而允许并行处理。但是，在处理大型元素向量时，乘法可能仍然**很慢**，并且需要**大量的内存资源**。此外，MSM 还面临可扩展性问题，即使在广泛并行化时，它们也可能保持缓慢。另一方面，NTT 在算法过程中涉及频繁的数据混排，因此很难在计算集群中分布。由于需要从大型数据集中加载和清理元素，因此在硬件上运行时它们还需要大量带宽。

MSM 和 NTT 都可以在 GPU 上加速，尤其是 MSM 通过一种称为`Pippenger`的算法。此过程涉及使用 CUDA 或 OpenCL 将计算密集型任务从 CPU 重写到 GPU，从而允许直接在 GPU 上编译和执行代码。为了实现更细粒度的加速，开发人员可以通过最大限度地利用快速内存和最小化慢速访问内存来优化内存使用，从而减少昂贵的数据传输，尤其是在 CPU 和 GPU 之间。

### FPGA

提供可编程的硬件结构，可以多次重新配置，与 ASIC 相比，**可降低制造成本**，并且在硬件资源使用方面比 GPU 具有更大的灵活性。虽然在 GPU 上优化 NTT 是可以实现的，但频繁的数据混排可能会**导致 GPU 和 CPU 之间的大量通信开销**。通过将逻辑直接实施到电路设计中，FPGA 可以更快地执行任务。由于其内存安全性和跨平台兼容性，大多数零知识证明的开源实现都是用 Rust 编写的。然而，FPGA 开发工具通常适用于 C/C++，开发周期可能会很长

### GPU

GPU 使用 CUDA 和 OpenCL 等有据可查的框架提供快速的开发时间，并且随时可用且经济高效。但是，GPU 功耗高，即使在利用数据和线程级并行性时也是如此。相比之下，FPGA 的开发周期更为复杂，需要专门的工程师，但允许进行低级优化并提供更低的延迟，尤其是对于大型数据流。FPGA 比 GPU 开发成本更高。

### ASIC

专用集成电路是为特定用途定制的，与 FPGA 相比，其设计和制造过程更加复杂且耗时。

ASIC 目前是最受推崇的硬件加速；然而，它们仍然有很大的进入门槛。**可编程性和逻辑修改在 ASIC 上很困难**，因为它们具有一次写入的业务逻辑，因此任何修改都需要完全重建系统。相反，FPGA 和 GPU 可以多次重新编程，允许在具有不同证明系统或更新的各种项目中使用相同的硬件。与 ASIC 相比，**这种可重新编程性使 FPGA 成为一种更通用的替代方案。**此外，ASIC 设计、生产和部署所需的时间通常为 12 到 18 个月或更长时间。

### ICICLE

repo：https://github.com/ingonyama-zk/icicle.git

使用 GPU 的 ZKP 的加密库。ICICLE 在 GPU 上实现了各种加密基元，例如椭圆曲线 （EC） 运算、多标量乘法 （MSM）、数论变换 （NTT） 和波塞冬哈希。多项式 API 为开发人员提供了多项式运算框架，以方便开发人员。此外，ICICLE 还绑定了 Rust 和 Golang，并与 Gnark 和 EZKL 等项目集成。它也可以在 Google Colab 中运行。Ingonyama正在推进零知识处理单元（ZPU），该单元被定义为“一种多功能和可编程的硬件加速器，旨在满足ZKP处理的新兴需求”。

### VPU

Verifiable Processing Unit 专为从 ZKP 到 FHE 的加密应用而设计的处理器。VPU 采用专为下一代密码学量身定制的定制指令集架构，包括 ZKP、FHE、MPC 和其他算法。它为 MSM、NTT、多项式求值以及波塞冬 （1、2）、布莱克和其他哈希函数提供加速。VPU 支持高达 384 位的多精度矢量通道，并包括一个 RISC-V 内核，以增强可编程性。它支持 PCIe 4.0 x16 通道，每个芯片提供高达 256 Gbps 的速率，并配备高带宽 DRAM。此外，Fabric Cryptography 还提供具有 3 个 FC1000 芯片的 PCIe 卡，用于并行 ZK 证明生成，一个 PCIe 接口，用于全面的片上验证和加密，以及用于递归 ZK 证明生成和挖掘工作负载的 DRAM。它们还提供服务器系统和数据中心，以支持更大的工作负载。
















