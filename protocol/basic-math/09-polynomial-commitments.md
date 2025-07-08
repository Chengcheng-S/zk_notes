# 多项式承诺 (Polynomial Commitments)

## 概述

多项式承诺是现代零知识证明系统的核心构建块，允许证明者承诺一个多项式而不泄露其系数，稍后可以证明该多项式在特定点的求值。这是PLONK、Halo2等现代ZKP系统的基础。

### 学习目标
- 理解多项式承诺的定义和安全性质
- 掌握KZG承诺方案的原理和实现
- 理解FRI协议和基于哈希的多项式承诺
- 掌握多项式承诺在ZKP中的应用

### 前置知识
- 多项式理论
- 椭圆曲线密码学
- 双线性映射
- 承诺方案基础

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
多项式承诺是现代ZKP的核心：
- PLONK协议的基础构建块
- 支持简洁的证明大小
- 实现高效的批量验证
- 支持通用可信设置

## 1. 多项式承诺的定义

### 1.1 基本定义

**多项式承诺方案**由以下算法组成：
- **Setup(1^λ, d) → pp**：生成支持度数≤d的多项式的公共参数
- **Commit(pp, f(X)) → (C, aux)**：承诺多项式f(X)，返回承诺C和辅助信息
- **Open(pp, C, z, y, π) → {0,1}**：验证f(z) = y的证明π
- **CreateProof(pp, f(X), z, aux) → π**：生成f(z) = f(z)的证明

### 1.2 安全性质

多项式承诺必须满足：

1. **完备性 (Completeness)**：诚实的证明总是被接受
2. **知识可靠性 (Knowledge Soundness)**：如果敌手能生成有效证明，则它知道对应的多项式
3. **隐藏性 (Hiding)**：承诺不泄露多项式信息（可选）

```python
from abc import ABC, abstractmethod
import numpy as np
from typing import Tuple, Any

class PolynomialCommitment(ABC):
    """多项式承诺方案抽象基类"""
    
    @abstractmethod
    def setup(self, max_degree: int) -> Any:
        """生成公共参数"""
        pass
    
    @abstractmethod
    def commit(self, polynomial: np.ndarray, pp: Any) -> Tuple[Any, Any]:
        """承诺多项式，返回(承诺, 辅助信息)"""
        pass
    
    @abstractmethod
    def create_proof(self, polynomial: np.ndarray, point: int, pp: Any, aux: Any) -> Any:
        """创建求值证明"""
        pass
    
    @abstractmethod
    def verify_proof(self, commitment: Any, point: int, value: int, proof: Any, pp: Any) -> bool:
        """验证求值证明"""
        pass
```

## 2. KZG多项式承诺

### 2.1 KZG方案原理

KZG（Kate-Zaverucha-Goldberg）承诺基于双线性映射构造：

**Setup**：选择随机数τ，计算：
$$pp = (g, g^τ, g^{τ^2}, ..., g^{τ^d}, h, h^τ)$$

**Commit**：对多项式f(X) = ΣᵢaᵢXⁱ，计算：
$$C = g^{f(τ)} = \prod_{i=0}^d (g^{τ^i})^{a_i}$$

**Prove**：证明f(z) = y，计算商多项式：
$$q(X) = \frac{f(X) - y}{X - z}$$
证明为：$$π = g^{q(τ)}$$

**Verify**：检查配对等式：
$$e(C / g^y, h) = e(π, h^τ / h^z)$$

### 2.2 KZG实现

```python
class KZGCommitment(PolynomialCommitment):
    """KZG多项式承诺实现"""
    
    def __init__(self, curve_params):
        self.G1 = curve_params['G1']
        self.G2 = curve_params['G2']
        self.pairing = curve_params['pairing']
        self.field_prime = curve_params['field_prime']
    
    def setup(self, max_degree: int) -> dict:
        """可信设置生成"""
        # 在实际应用中，τ必须被销毁（toxic waste）
        tau = random.randint(1, self.field_prime - 1)
        
        # 计算 [τ^i]₁ for i = 0, ..., max_degree
        powers_of_tau_g1 = []
        tau_power = 1
        for i in range(max_degree + 1):
            powers_of_tau_g1.append(self.G1.multiply(tau_power))
            tau_power = (tau_power * tau) % self.field_prime
        
        # 计算 [τ]₂
        tau_g2 = self.G2.multiply(tau)
        
        return {
            'powers_of_tau_g1': powers_of_tau_g1,
            'tau_g2': tau_g2,
            'g1': self.G1.generator(),
            'g2': self.G2.generator()
        }
    
    def commit(self, polynomial: np.ndarray, pp: dict) -> Tuple[Any, Any]:
        """承诺多项式"""
        commitment = self.G1.identity()
        
        for i, coeff in enumerate(polynomial):
            if coeff != 0:
                term = pp['powers_of_tau_g1'][i].multiply(coeff)
                commitment = commitment.add(term)
        
        return commitment, polynomial  # 辅助信息是多项式本身
    
    def create_proof(self, polynomial: np.ndarray, point: int, pp: dict, aux: Any) -> Any:
        """创建求值证明"""
        # 计算 f(point)
        value = self.evaluate_polynomial(polynomial, point)
        
        # 计算商多项式 q(X) = (f(X) - f(point)) / (X - point)
        quotient = self.compute_quotient_polynomial(polynomial, point, value)
        
        # 承诺商多项式
        proof, _ = self.commit(quotient, pp)
        
        return proof
    
    def verify_proof(self, commitment: Any, point: int, value: int, proof: Any, pp: dict) -> bool:
        """验证求值证明"""
        # 计算 C / g^value
        g_value = pp['g1'].multiply(value)
        left_pairing_input = commitment.subtract(g_value)
        
        # 计算 [τ - point]₂
        point_g2 = pp['g2'].multiply(point)
        right_pairing_input = pp['tau_g2'].subtract(point_g2)
        
        # 检查配对等式: e(C / g^value, g₂) = e(π, [τ - point]₂)
        left_pairing = self.pairing(left_pairing_input, pp['g2'])
        right_pairing = self.pairing(proof, right_pairing_input)
        
        return left_pairing == right_pairing
    
    def evaluate_polynomial(self, polynomial: np.ndarray, point: int) -> int:
        """计算多项式在给定点的值"""
        result = 0
        point_power = 1
        
        for coeff in polynomial:
            result = (result + coeff * point_power) % self.field_prime
            point_power = (point_power * point) % self.field_prime
        
        return result
    
    def compute_quotient_polynomial(self, polynomial: np.ndarray, point: int, value: int) -> np.ndarray:
        """计算商多项式 (f(X) - value) / (X - point)"""
        # f(X) - value
        adjusted_poly = polynomial.copy()
        adjusted_poly[0] = (adjusted_poly[0] - value) % self.field_prime
        
        # 多项式除法
        quotient = np.zeros(len(polynomial) - 1, dtype=int)
        remainder = adjusted_poly.copy()
        
        for i in range(len(quotient) - 1, -1, -1):
            if len(remainder) > i + 1:
                coeff = remainder[i + 1]
                quotient[i] = coeff
                
                # 减去 coeff * (X - point) * X^i
                if i + 1 < len(remainder):
                    remainder[i + 1] = (remainder[i + 1] - coeff) % self.field_prime
                if i < len(remainder):
                    remainder[i] = (remainder[i] + coeff * point) % self.field_prime
        
        return quotient

# 使用示例
def demo_kzg_commitment():
    """KZG承诺演示"""
    # 模拟椭圆曲线参数（实际应用中需要真实的椭圆曲线）
    curve_params = {
        'G1': MockEllipticCurveGroup(),
        'G2': MockEllipticCurveGroup(),
        'pairing': mock_pairing,
        'field_prime': 2**255 - 19  # 示例素数
    }
    
    kzg = KZGCommitment(curve_params)
    
    # 设置
    max_degree = 10
    pp = kzg.setup(max_degree)
    
    # 多项式 f(X) = 3X³ + 2X² + X + 5
    polynomial = np.array([5, 1, 2, 3, 0, 0, 0, 0, 0, 0, 0])
    
    # 承诺
    commitment, aux = kzg.commit(polynomial, pp)
    
    # 证明 f(7) = ?
    point = 7
    value = kzg.evaluate_polynomial(polynomial, point)
    proof = kzg.create_proof(polynomial, point, pp, aux)
    
    # 验证
    is_valid = kzg.verify_proof(commitment, point, value, proof, pp)
    print(f"KZG证明验证结果: {is_valid}")
    print(f"f({point}) = {value}")
```

## 3. 批量证明和聚合

### 3.1 批量求值证明

KZG支持高效的批量证明，可以同时证明多个点的求值：

```python
class BatchKZGCommitment(KZGCommitment):
    """支持批量证明的KZG承诺"""
    
    def create_batch_proof(self, polynomial: np.ndarray, points: list, pp: dict, aux: Any) -> Any:
        """创建批量求值证明"""
        # 计算插值多项式 I(X) 使得 I(zᵢ) = f(zᵢ)
        values = [self.evaluate_polynomial(polynomial, point) for point in points]
        interpolation_poly = self.lagrange_interpolation(points, values)
        
        # 计算零化多项式 Z(X) = ∏(X - zᵢ)
        zero_poly = self.compute_zero_polynomial(points)
        
        # 计算商多项式 q(X) = (f(X) - I(X)) / Z(X)
        numerator = self.subtract_polynomials(polynomial, interpolation_poly)
        quotient = self.divide_polynomials(numerator, zero_poly)
        
        # 承诺商多项式
        proof, _ = self.commit(quotient, pp)
        
        return proof, values
    
    def verify_batch_proof(self, commitment: Any, points: list, values: list, proof: Any, pp: dict) -> bool:
        """验证批量求值证明"""
        # 计算插值多项式承诺
        interpolation_poly = self.lagrange_interpolation(points, values)
        interpolation_commitment, _ = self.commit(interpolation_poly, pp)
        
        # 计算零化多项式承诺
        zero_poly = self.compute_zero_polynomial(points)
        zero_commitment, _ = self.commit(zero_poly, pp)
        
        # 验证: e(C - I_commitment, g₂) = e(proof, Z_commitment)
        left_input = commitment.subtract(interpolation_commitment)
        left_pairing = self.pairing(left_input, pp['g2'])
        right_pairing = self.pairing(proof, zero_commitment)
        
        return left_pairing == right_pairing
```

## 4. FRI协议

### 4.1 FRI原理

FRI（Fast Reed-Solomon Interactive Oracle Proof）是基于哈希的多项式承诺方案，不需要可信设置：

**核心思想**：通过递归减少多项式度数来证明多项式的低度性质。

```python
class FRICommitment(PolynomialCommitment):
    """FRI多项式承诺实现"""
    
    def __init__(self, hash_function, field_prime):
        self.hash = hash_function
        self.field_prime = field_prime
    
    def setup(self, max_degree: int) -> dict:
        """FRI不需要可信设置"""
        return {
            'max_degree': max_degree,
            'domain_size': 2 ** (max_degree.bit_length())
        }
    
    def commit(self, polynomial: np.ndarray, pp: dict) -> Tuple[Any, Any]:
        """使用Merkle树承诺多项式的求值"""
        domain_size = pp['domain_size']
        
        # 在大域上求值多项式
        evaluations = self.evaluate_on_domain(polynomial, domain_size)
        
        # 构建Merkle树
        merkle_tree = self.build_merkle_tree(evaluations)
        
        return merkle_tree.root, {
            'polynomial': polynomial,
            'evaluations': evaluations,
            'merkle_tree': merkle_tree
        }
    
    def create_proof(self, polynomial: np.ndarray, point: int, pp: dict, aux: Any) -> Any:
        """创建FRI证明"""
        # 这里简化实现，实际FRI协议更复杂
        evaluations = aux['evaluations']
        merkle_tree = aux['merkle_tree']
        
        # 找到点在域中的位置
        domain_index = self.find_domain_index(point, pp['domain_size'])
        
        # 生成Merkle路径
        merkle_path = merkle_tree.get_path(domain_index)
        
        return {
            'value': evaluations[domain_index],
            'merkle_path': merkle_path,
            'domain_index': domain_index
        }
    
    def verify_proof(self, commitment: Any, point: int, value: int, proof: Any, pp: dict) -> bool:
        """验证FRI证明"""
        # 验证Merkle路径
        return self.verify_merkle_path(
            commitment,
            proof['value'],
            proof['domain_index'],
            proof['merkle_path']
        ) and proof['value'] == value
```

## 5. ZKP中的应用

### 5.1 PLONK协议中的应用

```python
class PLONKWithKZG:
    """使用KZG承诺的PLONK协议"""
    
    def __init__(self, kzg_commitment):
        self.kzg = kzg_commitment
    
    def prove(self, circuit, witness, pp):
        """生成PLONK证明"""
        # 1. 构造多项式
        a_poly, b_poly, c_poly = self.construct_wire_polynomials(circuit, witness)
        z_poly = self.construct_permutation_polynomial(circuit, witness)
        
        # 2. 承诺多项式
        a_commit, a_aux = self.kzg.commit(a_poly, pp['kzg_pp'])
        b_commit, b_aux = self.kzg.commit(b_poly, pp['kzg_pp'])
        c_commit, c_aux = self.kzg.commit(c_poly, pp['kzg_pp'])
        z_commit, z_aux = self.kzg.commit(z_poly, pp['kzg_pp'])
        
        # 3. 生成挑战
        challenges = self.generate_challenges([a_commit, b_commit, c_commit, z_commit])
        
        # 4. 构造商多项式
        quotient_poly = self.construct_quotient_polynomial(
            a_poly, b_poly, c_poly, z_poly, challenges, pp
        )
        
        # 5. 承诺商多项式
        quotient_commit, quotient_aux = self.kzg.commit(quotient_poly, pp['kzg_pp'])
        
        # 6. 生成求值证明
        eval_challenge = self.generate_evaluation_challenge(quotient_commit)
        
        proofs = {}
        for poly_name, (poly, aux) in [
            ('a', (a_poly, a_aux)),
            ('b', (b_poly, b_aux)),
            ('c', (c_poly, c_aux)),
            ('z', (z_poly, z_aux)),
            ('quotient', (quotient_poly, quotient_aux))
        ]:
            proofs[poly_name] = self.kzg.create_proof(
                poly, eval_challenge, pp['kzg_pp'], aux
            )
        
        return {
            'commitments': {
                'a': a_commit,
                'b': b_commit,
                'c': c_commit,
                'z': z_commit,
                'quotient': quotient_commit
            },
            'proofs': proofs,
            'challenges': challenges,
            'eval_challenge': eval_challenge
        }
```

## 6. 性能分析和优化

### 6.1 证明大小比较

| 方案 | 证明大小 | 验证时间 | 可信设置 |
|------|----------|----------|----------|
| KZG | O(1) | O(1) | 需要 |
| FRI | O(log d) | O(log d) | 不需要 |
| IPA | O(log d) | O(log d) | 不需要 |

### 6.2 优化技术

```python
class OptimizedKZG(KZGCommitment):
    """优化的KZG实现"""
    
    def __init__(self, curve_params):
        super().__init__(curve_params)
        self.precomputed_windows = {}
    
    def precompute_windows(self, pp: dict, window_size: int = 4):
        """预计算窗口以加速多标量乘法"""
        powers = pp['powers_of_tau_g1']
        
        for i in range(0, len(powers), window_size):
            window = powers[i:i+window_size]
            self.precomputed_windows[i] = self.precompute_window_table(window)
    
    def fast_commit(self, polynomial: np.ndarray, pp: dict) -> Tuple[Any, Any]:
        """使用预计算表的快速承诺"""
        if not self.precomputed_windows:
            self.precompute_windows(pp)
        
        # 使用窗口方法进行多标量乘法
        commitment = self.multi_scalar_multiplication(
            polynomial, self.precomputed_windows
        )
        
        return commitment, polynomial
```

## 练习与思考

### 理论练习

1. **安全性分析**：
   - 证明KZG承诺的绑定性基于q-SDH假设
   - 分析FRI协议的可靠性误差

2. **效率分析**：
   - 比较不同多项式承诺方案的渐近复杂度
   - 分析批量证明的效率提升

### 编程练习

1. **实现简化的KZG**：
   ```python
   # 练习：实现支持小度数多项式的KZG承诺
   def implement_simple_kzg():
       # 你的实现
       pass
   ```

2. **批量验证优化**：
   ```python
   # 练习：实现高效的批量验证算法
   def batch_verify_optimized():
       # 你的实现
       pass
   ```

## 参考资料

### 经典论文
- **《Constant-Size Commitments to Polynomials and Their Applications》** - Kate, Zaverucha, Goldberg (2010)
- **《Fast Reed-Solomon Interactive Oracle Proofs of Proximity》** - Ben-Sasson et al. (2018)
- **《Bulletproofs》** - Bünz et al. (2018)

### 实现参考
- **arkworks-rs**: Rust实现的密码学库
- **gnark**: Go实现的ZKP库
- **circom**: 电路编译器

### 进阶阅读
- **《PLONK》** - Gabizon, Williamson, Ciobotaru (2019)
- **《Halo》** - Bowe, Grigg, Hopwood (2019)
- **《STARK》** - Ben-Sasson et al. (2018)