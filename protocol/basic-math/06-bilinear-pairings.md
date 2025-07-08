# 双线性映射 (Bilinear Pairings)

## 概述

双线性映射是现代密码学的重要工具，特别在零知识证明中用于构造简洁的证明系统。本章介绍双线性映射的数学理论和密码学应用。

### 学习目标
- 理解双线性映射的数学定义
- 掌握Weil配对和Tate配对
- 理解配对友好椭圆曲线
- 掌握基于配对的密码学协议

### 前置知识
- 椭圆曲线密码学
- 有限域理论
- 群论基础

### 在ZKP中的重要性 ⭐⭐⭐⭐
双线性映射在ZKP中的应用：
- Groth16等简洁证明系统
- BLS签名聚合
- 多项式承诺方案
- 身份基加密

## 1. 双线性映射的定义

### 1.1 数学定义

**双线性映射**：设 G₁, G₂, G_T 是三个循环群，阶都为素数 r。双线性映射是函数：
$$e: G_1 \times G_2 \rightarrow G_T$$

满足以下性质：

1. **双线性**：
   - ∀P ∈ G₁, Q, R ∈ G₂: e(P, Q + R) = e(P, Q) · e(P, R)
   - ∀P, Q ∈ G₁, R ∈ G₂: e(P + Q, R) = e(P, R) · e(Q, R)

2. **非退化性**：
   - 如果 e(P, Q) = 1_T 对所有 P ∈ G₁ 成立，则 Q = O₂
   - 如果 e(P, Q) = 1_T 对所有 Q ∈ G₂ 成立，则 P = O₁

3. **可计算性**：存在多项式时间算法计算 e(P, Q)

### 1.2 配对类型

根据群的关系，配对分为三种类型：

- **Type-1**：G₁ = G₂（对称配对）
- **Type-2**：G₁ ≠ G₂，但存在有效同态 φ: G₂ → G₁
- **Type-3**：G₁ ≠ G₂，且不存在已知的有效同态

```python
from abc import ABC, abstractmethod

class BilinearPairing(ABC):
    """双线性映射抽象基类"""
    
    def __init__(self, G1, G2, GT, r):
        self.G1 = G1  # 群 G₁
        self.G2 = G2  # 群 G₂  
        self.GT = GT  # 目标群 G_T
        self.r = r    # 群的阶
    
    @abstractmethod
    def pairing(self, P, Q):
        """计算配对 e(P, Q)"""
        pass
    
    def verify_bilinearity(self, P1, P2, Q1, Q2):
        """验证双线性性质"""
        # e(P1 + P2, Q1) = e(P1, Q1) * e(P2, Q1)
        left = self.pairing(P1 + P2, Q1)
        right = self.pairing(P1, Q1) * self.pairing(P2, Q1)
        
        # e(P1, Q1 + Q2) = e(P1, Q1) * e(P1, Q2)
        left2 = self.pairing(P1, Q1 + Q2)
        right2 = self.pairing(P1, Q1) * self.pairing(P1, Q2)
        
        return left == right and left2 == right2
    
    def miller_algorithm(self, P, Q, r):
        """Miller算法计算配对（简化版）"""
        # 这是配对计算的核心算法
        # 实际实现非常复杂，这里只展示基本结构
        
        def line_function(R, S, P):
            """直线函数"""
            # 计算通过点R和S的直线在点P处的值
            # 实际实现需要考虑椭圆曲线的具体形式
            pass
        
        f = 1  # 累积器
        T = P  # 当前点
        
        # 二进制展开r
        bits = bin(r)[2:]
        
        for i in range(1, len(bits)):
            # 倍点操作
            f = f * f * line_function(T, T, Q)
            T = 2 * T
            
            if bits[i] == '1':
                # 加点操作
                f = f * line_function(T, P, Q)
                T = T + P
        
        return f
```

## 2. 配对友好椭圆曲线

### 2.1 嵌入度

**嵌入度 (Embedding Degree)**：对于椭圆曲线 E/F_q，嵌入度 k 是使得 r | (q^k - 1) 的最小正整数，其中 r 是曲线的阶。

**意义**：嵌入度决定了配对计算的效率和安全性。

### 2.2 BN曲线族

**BN曲线**：由Barreto和Naehrig提出的配对友好曲线族：
- **参数化**：q = 36u⁴ + 36u³ + 24u² + 6u + 1, r = 36u⁴ + 36u³ + 18u² + 6u + 1
- **嵌入度**：k = 12
- **扭曲度**：d = 6

```python
class BN254Pairing:
    """BN254曲线的配对实现（简化版）"""
    
    def __init__(self):
        # BN254参数
        self.q = 21888242871839275222246405745257275088696311157297823662689037894645226208583
        self.r = 21888242871839275222246405745257275088548364400416034343698204186575808495617
        self.embedding_degree = 12
        
        # 曲线参数：y² = x³ + 3
        self.b = 3
        
    def ate_pairing(self, P, Q):
        """Ate配对（BN曲线的优化配对）"""
        # Ate配对是Tate配对的优化版本
        # 循环长度从r减少到约log(r)
        
        # 计算6u + 2（BN曲线的Ate参数）
        u = -4965661367192848881  # BN254的u参数
        loop_count = 6 * u + 2
        
        # Miller循环
        f = self._miller_loop(P, Q, loop_count)
        
        # 最终幂运算
        result = self._final_exponentiation(f)
        
        return result
    
    def _miller_loop(self, P, Q, n):
        """Miller循环"""
        # 简化实现，实际需要处理扩域运算
        f = 1
        T = Q
        
        bits = bin(abs(n))[2:]
        for i in range(1, len(bits)):
            f = f * f  # 平方
            T = self._double_line(T, P)
            
            if bits[i] == '1':
                f = f  # 乘以直线函数
                T = self._add_line(T, Q, P)
        
        if n < 0:
            f = 1 / f
            
        return f
    
    def _final_exponentiation(self, f):
        """最终幂运算：f^((q^12-1)/r)"""
        # BN曲线的最终幂运算可以分解为两步：
        # 1. 容易部分：f^((q^6-1)(q^2+1))
        # 2. 困难部分：f^((q^4-q^2+1)/r)
        
        # 容易部分
        f_q6 = self._frobenius_power(f, 6)
        f_inv = 1 / f
        f1 = f_q6 * f_inv  # f^(q^6-1)
        
        f_q2 = self._frobenius_power(f1, 2)
        f2 = f1 * f_q2    # f^((q^6-1)(q^2+1))
        
        # 困难部分（简化）
        result = self._hard_part_exponentiation(f2)
        
        return result
    
    def _frobenius_power(self, f, power):
        """Frobenius自同态的幂"""
        # 在扩域中计算f^(q^power)
        # 实际实现需要处理F_q^12的表示
        return f  # 简化
    
    def _hard_part_exponentiation(self, f):
        """困难部分的幂运算"""
        # 使用优化的算法计算
        return f  # 简化

# 使用示例
pairing = BN254Pairing()
```

### 2.3 BLS12曲线族

**BLS12曲线**：由Barreto, Lynn和Scott提出：
- **嵌入度**：k = 12
- **更高的安全性**：BLS12-381提供128位安全级别
- **更好的性能**：优化的配对计算

```python
class BLS12_381_Pairing:
    """BLS12-381曲线的配对"""
    
    def __init__(self):
        # BLS12-381参数
        self.q = 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787
        self.r = 52435875175126190479447740508185965837690552500527637822603658699938581184513
        
        # 曲线参数：y² = x³ + 4
        self.b = 4
        
    def optimal_ate_pairing(self, P, Q):
        """优化Ate配对"""
        # BLS12-381的优化参数
        x = -15132376222941642752  # BLS12-381的x参数
        
        # Miller循环
        f = self._miller_loop_bls12(P, Q, x)
        
        # 最终幂运算
        result = self._final_exp_bls12(f)
        
        return result
```

## 3. 基于配对的密码学

### 3.1 三方Diffie-Hellman

```python
class TripartiteDH:
    """基于配对的三方密钥交换"""
    
    def __init__(self, pairing, G1, G2, GT):
        self.pairing = pairing
        self.G1 = G1
        self.G2 = G2
        self.GT = GT
    
    def setup(self):
        """系统设置"""
        # 选择生成元
        P = self.G1.generator()
        Q = self.G2.generator()
        return P, Q
    
    def key_exchange(self, P, Q):
        """三方密钥交换协议"""
        # Alice选择私钥a，计算aP, aQ
        # Bob选择私钥b，计算bP, bQ  
        # Carol选择私钥c，计算cP, cQ
        
        # 共享密钥：e(P,Q)^(abc)
        # Alice计算：e(bP, cQ)^a
        # Bob计算：e(cP, aQ)^b
        # Carol计算：e(aP, bQ)^c
        
        import random
        a = random.randint(1, self.pairing.r - 1)
        b = random.randint(1, self.pairing.r - 1)
        c = random.randint(1, self.pairing.r - 1)
        
        # 公钥
        aP, aQ = a * P, a * Q
        bP, bQ = b * P, b * Q
        cP, cQ = c * P, c * Q
        
        # 共享密钥计算
        key_alice = self.pairing.pairing(bP, cQ) ** a
        key_bob = self.pairing.pairing(cP, aQ) ** b
        key_carol = self.pairing.pairing(aP, bQ) ** c
        
        return key_alice, key_bob, key_carol
```

### 3.2 BLS签名

```python
class BLSSignature:
    """BLS签名方案"""
    
    def __init__(self, pairing, G1, G2, GT):
        self.pairing = pairing
        self.G1 = G1  # 签名群
        self.G2 = G2  # 公钥群
        self.GT = GT  # 目标群
    
    def keygen(self):
        """密钥生成"""
        import random
        sk = random.randint(1, self.pairing.r - 1)  # 私钥
        pk = sk * self.G2.generator()               # 公钥
        return sk, pk
    
    def sign(self, message, sk):
        """签名"""
        # 将消息哈希到G1
        H_m = self.hash_to_G1(message)
        # 签名：σ = sk * H(m)
        signature = sk * H_m
        return signature
    
    def verify(self, message, signature, pk):
        """验证"""
        H_m = self.hash_to_G1(message)
        G = self.G2.generator()
        
        # 验证：e(σ, G) = e(H(m), pk)
        left = self.pairing.pairing(signature, G)
        right = self.pairing.pairing(H_m, pk)
        
        return left == right
    
    def aggregate_signatures(self, signatures):
        """签名聚合"""
        result = self.G1.identity()
        for sig in signatures:
            result = result + sig
        return result
    
    def aggregate_verify(self, messages, aggregate_sig, public_keys):
        """聚合验证"""
        G = self.G2.generator()
        
        # 计算 e(σ_agg, G)
        left = self.pairing.pairing(aggregate_sig, G)
        
        # 计算 ∏ e(H(m_i), pk_i)
        right = self.GT.identity()
        for msg, pk in zip(messages, public_keys):
            H_m = self.hash_to_G1(msg)
            right = right * self.pairing.pairing(H_m, pk)
        
        return left == right
    
    def hash_to_G1(self, message):
        """将消息哈希到G1（简化实现）"""
        # 实际实现需要使用安全的哈希到曲线算法
        import hashlib
        hash_value = int(hashlib.sha256(message.encode()).hexdigest(), 16)
        return hash_value * self.G1.generator()
```

## 4. ZKP中的应用

### 4.1 Groth16证明系统

```python
class Groth16Setup:
    """Groth16的可信设置"""
    
    def __init__(self, pairing, circuit):
        self.pairing = pairing
        self.circuit = circuit
    
    def setup(self):
        """生成CRS（公共参考字符串）"""
        import random
        
        # 随机选择有毒废料
        alpha = random.randint(1, self.pairing.r - 1)
        beta = random.randint(1, self.pairing.r - 1)
        gamma = random.randint(1, self.pairing.r - 1)
        delta = random.randint(1, self.pairing.r - 1)
        x = random.randint(1, self.pairing.r - 1)
        
        # 生成proving key和verification key
        pk = self._generate_proving_key(alpha, beta, gamma, delta, x)
        vk = self._generate_verification_key(alpha, beta, gamma, delta, x)
        
        return pk, vk
    
    def _generate_proving_key(self, alpha, beta, gamma, delta, x):
        """生成证明密钥"""
        G1_gen = self.pairing.G1.generator()
        G2_gen = self.pairing.G2.generator()
        
        # [α]₁, [β]₁, [δ]₁
        alpha_1 = alpha * G1_gen
        beta_1 = beta * G1_gen
        delta_1 = delta * G1_gen
        
        # [β]₂, [γ]₂, [δ]₂
        beta_2 = beta * G2_gen
        gamma_2 = gamma * G2_gen
        delta_2 = delta * G2_gen
        
        # 其他CRS元素...
        
        return {
            'alpha_1': alpha_1,
            'beta_1': beta_1,
            'delta_1': delta_1,
            'beta_2': beta_2,
            'gamma_2': gamma_2,
            'delta_2': delta_2,
            # ... 更多元素
        }
    
    def _generate_verification_key(self, alpha, beta, gamma, delta, x):
        """生成验证密钥"""
        G1_gen = self.pairing.G1.generator()
        G2_gen = self.pairing.G2.generator()
        
        return {
            'alpha_1': alpha * G1_gen,
            'beta_2': beta * G2_gen,
            'gamma_2': gamma * G2_gen,
            'delta_2': delta * G2_gen,
            # IC (input commitment) 元素
        }

class Groth16Prover:
    """Groth16证明者"""
    
    def prove(self, pk, witness, statement):
        """生成证明"""
        import random
        
        # 随机选择r, s
        r = random.randint(1, self.pairing.r - 1)
        s = random.randint(1, self.pairing.r - 1)
        
        # 计算证明元素
        # A = α + Σ aᵢuᵢ(x) + r·δ
        # B = β + Σ aᵢvᵢ(x) + s·δ  
        # C = (Σ aᵢwᵢ(x) + h(x)t(x))/δ + A·s + B·r - r·s·δ
        
        A = self._compute_A(pk, witness, r)
        B = self._compute_B(pk, witness, s)
        C = self._compute_C(pk, witness, A, B, r, s)
        
        return {'A': A, 'B': B, 'C': C}
    
    def _compute_A(self, pk, witness, r):
        """计算证明元素A"""
        # 简化实现
        return pk['alpha_1'] + r * pk['delta_1']
    
    def _compute_B(self, pk, witness, s):
        """计算证明元素B"""
        # 简化实现
        return pk['beta_2'] + s * pk['delta_2']
    
    def _compute_C(self, pk, witness, A, B, r, s):
        """计算证明元素C"""
        # 简化实现
        return pk['delta_1']  # 占位符

class Groth16Verifier:
    """Groth16验证者"""
    
    def verify(self, vk, proof, public_inputs):
        """验证证明"""
        A, B, C = proof['A'], proof['B'], proof['C']
        
        # 计算输入承诺
        vk_x = self._compute_input_commitment(vk, public_inputs)
        
        # 配对检查：e(A,B) = e(α,β)·e(vk_x,γ)·e(C,δ)
        left = self.pairing.pairing(A, B)
        
        right = (self.pairing.pairing(vk['alpha_1'], vk['beta_2']) *
                self.pairing.pairing(vk_x, vk['gamma_2']) *
                self.pairing.pairing(C, vk['delta_2']))
        
        return left == right
    
    def _compute_input_commitment(self, vk, public_inputs):
        """计算输入承诺"""
        # vk_x = Σ aᵢ·IC[i] for public inputs
        result = vk['IC'][0]  # IC[0]对应常数项
        
        for i, input_val in enumerate(public_inputs):
            result = result + input_val * vk['IC'][i + 1]
        
        return result
```

## 参考资料

### 经典教材
- **《Introduction to Identity-Based Encryption》** - Boneh & Franklin
- **《Pairings for Cryptographers》** - Galbraith, Paterson, Smart
- **《Guide to Pairing-Based Cryptography》** - El Mrabet & Joye

### 重要论文
- **《Identity-Based Encryption from the Weil Pairing》** - Boneh & Franklin
- **《Short Signatures from the Weil Pairing》** - Boneh, Lynn, Shacham
- **《On the Size of Pairing-based Non-interactive Arguments》** - Groth