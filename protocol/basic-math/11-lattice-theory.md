# 格理论 (Lattice Theory)

## 概述

格理论是现代密码学的重要分支，特别在后量子密码学和零知识证明中发挥关键作用。格问题的困难性为新型密码学协议提供了安全基础。

### 学习目标
- 理解格的数学定义和基本性质
- 掌握最短向量问题(SVP)和最近向量问题(CVP)
- 理解格基约化算法(LLL算法)
- 掌握基于格的密码学协议

### 前置知识
- 线性代数基础
- 数论基础
- 群论基础
- 复杂性理论基础

### 在ZKP中的重要性 ⭐⭐⭐⭐
格理论在ZKP中的应用：
- 后量子安全的零知识证明
- 基于格的承诺方案
- 同态加密与ZKP结合
- 抗量子攻击的签名方案

## 1. 格的基本概念

### 1.1 格的定义

**格 (Lattice)**：给定线性无关向量 b₁, b₂, ..., bₙ ∈ ℝᵐ，由它们生成的格是：
$$L = \{a_1 b_1 + a_2 b_2 + \cdots + a_n b_n : a_i \in \mathbb{Z}\}$$

- **格基 (Basis)**：生成向量 {b₁, b₂, ..., bₙ}
- **格的维数**：基向量的个数 n
- **格的秩**：基向量张成的线性空间维数
- **满秩格**：n = m 的格

### 1.2 格的基本性质

**基本域 (Fundamental Domain)**：
$$\mathcal{F}(B) = \{Bx : x \in [0,1)^n\}$$

**格的行列式**：
$$\det(L) = |\det(B)|$$
其中 B 是格基矩阵。

**最短向量长度**：
$$\lambda_1(L) = \min_{v \in L \setminus \{0\}} \|v\|$$

```python
import numpy as np
from scipy.linalg import qr

class Lattice:
    """格的基本实现"""
    
    def __init__(self, basis_matrix):
        """
        初始化格
        basis_matrix: n×m 矩阵，每行是一个基向量
        """
        self.basis = np.array(basis_matrix, dtype=float)
        self.dimension = self.basis.shape[0]
        self.ambient_dimension = self.basis.shape[1]
    
    def determinant(self):
        """计算格的行列式"""
        if self.dimension == self.ambient_dimension:
            return abs(np.linalg.det(self.basis))
        else:
            # 对于非满秩格，计算 Gram 矩阵的行列式的平方根
            gram = np.dot(self.basis, self.basis.T)
            return np.sqrt(abs(np.linalg.det(gram)))
    
    def closest_vector_naive(self, target):
        """朴素的最近向量算法（仅用于小维数）"""
        # 这是一个指数时间算法，仅用于演示
        best_distance = float('inf')
        best_vector = None
        
        # 搜索范围（实际应用中需要更智能的界限）
        search_range = 10
        
        for coeffs in np.ndindex(*([2*search_range+1] * self.dimension)):
            coeffs = np.array(coeffs) - search_range
            lattice_vector = np.dot(coeffs, self.basis)
            distance = np.linalg.norm(target - lattice_vector)
            
            if distance < best_distance:
                best_distance = distance
                best_vector = lattice_vector
        
        return best_vector, best_distance

# 示例：2D格
basis = [[1, 0], [0.5, np.sqrt(3)/2]]  # 六角格
lattice = Lattice(basis)
print(f"格的行列式: {lattice.determinant():.4f}")

# 寻找最近向量
target = [0.7, 0.8]
closest, distance = lattice.closest_vector_naive(target)
print(f"目标点: {target}")
print(f"最近格点: {closest}")
print(f"距离: {distance:.4f}")
```

## 2. 困难问题

### 2.1 最短向量问题 (SVP)

**问题定义**：给定格 L，找到最短的非零格向量。

**判定版本**：给定格 L 和长度 d，判断是否存在长度 ≤ d 的非零格向量。

**近似版本**：找到长度至多为 γ·λ₁(L) 的非零格向量，其中 γ ≥ 1 是近似因子。

### 2.2 最近向量问题 (CVP)

**问题定义**：给定格 L 和目标向量 t，找到距离 t 最近的格向量。

**判定版本**：给定格 L、目标向量 t 和距离 d，判断是否存在距离 t 不超过 d 的格向量。

### 2.3 困难性分析

**定理**：SVP 和 CVP 在最坏情况下是 NP-困难的。

**平均情况困难性**：基于最坏情况到平均情况的归约，某些格问题的平均情况也是困难的。

```python
def svp_approximation_factor(dimension):
    """
    估计不同维数下SVP的近似因子
    基于已知的算法复杂性
    """
    # LLL算法的近似因子
    lll_factor = 2**(dimension/4)
    
    # BKZ算法的近似因子（块大小为β）
    def bkz_factor(beta):
        return (beta/(2*np.pi*np.e) * (np.pi*beta)**(1/beta))**(1/(2*(beta-1)))
    
    return {
        'LLL': lll_factor,
        'BKZ-20': bkz_factor(20),
        'BKZ-50': bkz_factor(50)
    }

# 不同维数的近似因子
for dim in [50, 100, 200, 500]:
    factors = svp_approximation_factor(dim)
    print(f"维数 {dim}:")
    for alg, factor in factors.items():
        print(f"  {alg}: {factor:.2f}")
    print()
```

## 3. LLL算法

### 3.1 算法原理

**LLL算法**（Lenstra-Lenstra-Lovász）是多项式时间的格基约化算法，产生"较短"的基向量。

**LLL约化条件**：
1. **尺寸约化**：|μᵢⱼ| ≤ 1/2 对所有 i > j
2. **Lovász条件**：δ|b*ᵢ|² ≤ |b*ᵢ₊₁ + μᵢ₊₁,ᵢb*ᵢ|² 对所有 i

其中 b*ᵢ 是Gram-Schmidt正交化向量，δ ∈ (1/4, 1) 是参数。

### 3.2 算法实现

```python
def gram_schmidt(basis):
    """Gram-Schmidt正交化"""
    basis = np.array(basis, dtype=float)
    n, m = basis.shape
    
    orthogonal = np.zeros_like(basis)
    mu = np.zeros((n, n))
    
    for i in range(n):
        orthogonal[i] = basis[i].copy()
        for j in range(i):
            mu[i, j] = np.dot(basis[i], orthogonal[j]) / np.dot(orthogonal[j], orthogonal[j])
            orthogonal[i] -= mu[i, j] * orthogonal[j]
    
    return orthogonal, mu

def lll_reduction(basis, delta=0.75):
    """LLL格基约化算法"""
    basis = np.array(basis, dtype=float)
    n = len(basis)
    
    # Gram-Schmidt正交化
    orthogonal, mu = gram_schmidt(basis)
    
    k = 1
    while k < n:
        # 尺寸约化
        for j in range(k-1, -1, -1):
            if abs(mu[k, j]) > 0.5:
                q = round(mu[k, j])
                basis[k] -= q * basis[j]
                # 更新μ值
                for i in range(j):
                    mu[k, i] -= q * mu[j, i]
                mu[k, j] -= q
        
        # 检查Lovász条件
        if (np.dot(orthogonal[k], orthogonal[k]) >= 
            (delta - mu[k, k-1]**2) * np.dot(orthogonal[k-1], orthogonal[k-1])):
            k += 1
        else:
            # 交换基向量
            basis[[k, k-1]] = basis[[k-1, k]]
            orthogonal, mu = gram_schmidt(basis)
            k = max(k-1, 1)
    
    return basis

# 示例：LLL约化
original_basis = [
    [1, 1, 1],
    [-1, 0, 2],
    [3, 5, 6]
]

print("原始基:")
for i, vec in enumerate(original_basis):
    print(f"b_{i+1} = {vec}")

reduced_basis = lll_reduction(original_basis)
print("\nLLL约化后的基:")
for i, vec in enumerate(reduced_basis):
    print(f"b'_{i+1} = {vec}")

# 计算基向量长度
print("\n基向量长度比较:")
for i in range(len(original_basis)):
    orig_len = np.linalg.norm(original_basis[i])
    red_len = np.linalg.norm(reduced_basis[i])
    print(f"向量 {i+1}: {orig_len:.3f} -> {red_len:.3f}")
```

## 4. 基于格的密码学

### 4.1 Learning With Errors (LWE)

**LWE问题**：给定 (A, b = As + e)，其中：
- A ∈ ℤₑⁿˣᵐ 是随机矩阵
- s ∈ ℤₑⁿ 是秘密向量
- e ∈ ℤₑᵐ 是小的错误向量

目标：恢复秘密向量 s。

```python
import numpy as np

class LWE:
    """Learning With Errors 问题"""
    
    def __init__(self, n, m, q, error_bound=1):
        """
        n: 秘密维数
        m: 样本数量
        q: 模数
        error_bound: 错误界限
        """
        self.n = n
        self.m = m
        self.q = q
        self.error_bound = error_bound
    
    def generate_instance(self):
        """生成LWE实例"""
        # 随机矩阵A
        A = np.random.randint(0, self.q, (self.m, self.n))
        
        # 秘密向量s
        s = np.random.randint(0, self.q, self.n)
        
        # 错误向量e（小的高斯错误）
        e = np.random.randint(-self.error_bound, self.error_bound + 1, self.m)
        
        # 计算b = As + e (mod q)
        b = (np.dot(A, s) + e) % self.q
        
        return A, b, s, e
    
    def encrypt(self, A, b, message_bit):
        """基于LWE的加密（简化版）"""
        # 随机选择子集
        subset = np.random.choice(self.m, self.n, replace=False)
        
        # 计算密文
        c1 = np.sum(A[subset], axis=0) % self.q
        c2 = (np.sum(b[subset]) + message_bit * (self.q // 2)) % self.q
        
        return c1, c2
    
    def decrypt(self, c1, c2, s):
        """解密"""
        # 计算 c2 - <c1, s>
        decryption = (c2 - np.dot(c1, s)) % self.q
        
        # 判断更接近0还是q/2
        if decryption < self.q // 4 or decryption > 3 * self.q // 4:
            return 0
        else:
            return 1

# 示例：LWE加密
lwe = LWE(n=10, m=20, q=97, error_bound=2)
A, b, s, e = lwe.generate_instance()

# 加密消息
message = 1
c1, c2 = lwe.encrypt(A, b, message)
decrypted = lwe.decrypt(c1, c2, s)

print(f"原始消息: {message}")
print(f"解密结果: {decrypted}")
print(f"解密正确: {message == decrypted}")
```

### 4.2 格基签名方案

```python
class LatticeSignature:
    """基于格的签名方案（简化版）"""
    
    def __init__(self, n, m, q):
        self.n = n
        self.m = m
        self.q = q
    
    def key_generation(self):
        """密钥生成"""
        # 生成随机矩阵A
        A = np.random.randint(0, self.q, (self.n, self.m))
        
        # 生成短的秘密矩阵S
        S = np.random.randint(-1, 2, (self.m, self.n))  # 三元分布
        
        # 计算公钥 T = AS (mod q)
        T = np.dot(A, S) % self.q
        
        return (A, T), S  # (公钥, 私钥)
    
    def sign(self, message, private_key, public_key):
        """签名生成（简化版）"""
        A, T = public_key
        S = private_key
        
        # 简化的Fiat-Shamir变换
        # 实际实现需要更复杂的拒绝采样
        
        # 生成随机向量y
        y = np.random.randint(-10, 11, self.m)
        
        # 计算承诺 c = Ay (mod q)
        c = np.dot(A, y) % self.q
        
        # 计算挑战（简化为消息哈希）
        challenge = hash(str(message) + str(c.tolist())) % self.q
        
        # 计算响应 z = y + challenge * s
        # 这里简化处理，实际需要拒绝采样
        s_flat = S.flatten()[:len(y)]  # 简化处理
        z = y + challenge * s_flat
        
        return challenge, z
    
    def verify(self, message, signature, public_key):
        """签名验证"""
        A, T = public_key
        challenge, z = signature
        
        # 重新计算承诺
        c_prime = np.dot(A, z) % self.q
        
        # 计算期望的挑战
        expected_challenge = hash(str(message) + str(c_prime.tolist())) % self.q
        
        return challenge == expected_challenge

# 示例：格基签名
sig_scheme = LatticeSignature(n=5, m=10, q=97)
public_key, private_key = sig_scheme.key_generation()

message = "Hello, Lattice Cryptography!"
signature = sig_scheme.sign(message, private_key, public_key)
is_valid = sig_scheme.verify(message, signature, public_key)

print(f"消息: {message}")
print(f"签名验证: {is_valid}")
```

## 5. ZKP中的应用

### 5.1 后量子零知识证明

基于格的零知识证明具有后量子安全性：

```python
class LatticeZKProof:
    """基于格的零知识证明（概念性实现）"""
    
    def __init__(self, n, m, q):
        self.n = n
        self.m = m
        self.q = q
    
    def setup(self):
        """设置公共参数"""
        # 生成随机矩阵A
        A = np.random.randint(0, self.q, (self.n, self.m))
        return A
    
    def prove_knowledge_of_short_vector(self, A, s):
        """
        证明知道短向量s使得As = t (mod q)
        这是一个简化的概念性实现
        """
        # 计算公共值
        t = np.dot(A, s) % self.q
        
        # 生成随机掩码
        r = np.random.randint(-100, 101, self.m)
        
        # 计算承诺
        commitment = np.dot(A, r) % self.q
        
        # 生成挑战（实际应用中应该是随机的）
        challenge = np.random.randint(0, 2)
        
        if challenge == 0:
            # 揭示掩码
            response = r
        else:
            # 揭示掩码+秘密
            response = (r + s) % self.q
        
        return t, commitment, challenge, response
    
    def verify_proof(self, A, proof):
        """验证证明"""
        t, commitment, challenge, response = proof
        
        if challenge == 0:
            # 验证承诺
            expected_commitment = np.dot(A, response) % self.q
            return np.array_equal(commitment, expected_commitment)
        else:
            # 验证 A*response = commitment + t
            expected = (commitment + t) % self.q
            actual = np.dot(A, response) % self.q
            return np.array_equal(expected, actual)

# 示例：格基零知识证明
zkp = LatticeZKProof(n=5, m=8, q=97)
A = zkp.setup()

# 生成短秘密向量
secret = np.random.randint(-2, 3, zkp.m)

# 生成证明
proof = zkp.prove_knowledge_of_short_vector(A, secret)

# 验证证明
is_valid = zkp.verify_proof(A, proof)
print(f"零知识证明验证: {is_valid}")
```

## 6. 练习与思考

### 6.1 理论练习

1. **格的基本性质**：
   - 证明格的行列式不依赖于基的选择
   - 证明二维格的最短向量可以在多项式时间内找到

2. **LLL算法分析**：
   - 分析LLL算法的时间复杂度
   - 证明LLL约化基的第一个向量长度的上界

3. **困难性分析**：
   - 理解SVP的NP困难性证明思路
   - 分析不同近似因子下格问题的困难性

### 6.2 编程练习

1. **实现格算法**：
   ```python
   # 练习1：实现更高效的LLL算法
   def improved_lll(basis, delta=0.75):
       # TODO: 实现优化的LLL算法
       pass
   
   # 练习2：实现BKZ算法的简化版本
   def simple_bkz(basis, block_size=10):
       # TODO: 实现BKZ算法
       pass
   
   # 练习3：实现基于格的哈希函数
   def lattice_hash(message, A, q):
       # TODO: 实现基于LWE的哈希函数
       pass
   ```

2. **性能分析**：
   - 比较不同维数下LLL算法的性能
   - 分析格基约化对最短向量近似的影响

## 7. 参考资料

### 经典教材
- **《An Introduction to Mathematical Cryptography》** - Hoffstein, Pipher, Silverman
- **《A Course in Computational Algebraic Number Theory》** - Henri Cohen
- **《Lattices in Cryptography》** - Daniele Micciancio, Shafi Goldwasser

### 重要论文
- **《Factoring polynomials with rational coefficients》** - A.K. Lenstra, H.W. Lenstra, L. Lovász (1982)
- **《On Lattices, Learning with Errors, Random Linear Codes, and Cryptography》** - Oded Regev (2005)
- **《Efficient Lattice (H)IBE in the Standard Model》** - Shweta Agrawal et al. (2010)

### ZKP相关
- **《Lattice-Based Zero-Knowledge Arguments for Integer Relations》** - Stern (1996)
- **《Post-Quantum Zero-Knowledge and Signatures from Symmetric-Key Primitives》** - Giacomelli et al. (2017)
- **《Bulletproofs: Short Proofs for Confidential Transactions and More》** - Bünz et al. (2018)

### 在线资源
- **Lattice Cryptography Bibliography**: https://www.latticecrypto.org/
- **NIST Post-Quantum Cryptography**: https://csrc.nist.gov/projects/post-quantum-cryptography
- **Lattice-based Cryptography Course**: MIT 6.876/18.426