# 哈希函数理论 (Hash Function Theory)

## 概述

哈希函数是密码学的基础工具，在零知识证明中用于构造Merkle树、随机预言机模型和Fiat-Shamir变换。本章涵盖哈希函数的数学理论和密码学应用。

### 学习目标
- 理解哈希函数的定义和安全性质
- 掌握SHA系列和其他密码学哈希函数
- 理解抗碰撞性和单向性
- 掌握哈希函数在ZKP中的应用

### 前置知识
- 数论基础
- 概率论基础
- 复杂性理论基础

### 在ZKP中的重要性 ⭐⭐⭐⭐
哈希函数在ZKP中的应用：
- Merkle树构造和验证
- Fiat-Shamir变换实现非交互性
- 随机预言机模型
- 承诺方案的构造

## 核心概念

### 1. 哈希函数的定义

**哈希函数**：一个函数 H: {0,1}* → {0,1}^n，将任意长度的输入映射到固定长度的输出。

基本性质：
1. **确定性**：相同输入总是产生相同输出
2. **高效性**：计算H(x)应该是多项式时间的
3. **雪崩效应**：输入的微小变化导致输出的巨大变化

### 2. 密码学安全性质

#### 2.1 抗原像性 (Preimage Resistance)
给定哈希值h，找到满足H(x) = h的x在计算上是困难的。

#### 2.2 抗第二原像性 (Second Preimage Resistance)
给定x₁，找到x₂ ≠ x₁使得H(x₁) = H(x₂)在计算上是困难的。

#### 2.3 抗碰撞性 (Collision Resistance)
找到任意两个不同的输入x₁, x₂使得H(x₁) = H(x₂)在计算上是困难的。

```python
import hashlib
import os

class CryptographicHash:
    """密码学哈希函数包装类"""
    
    def __init__(self, algorithm='sha256'):
        self.algorithm = algorithm
        
    def hash(self, data):
        """计算数据的哈希值"""
        if isinstance(data, str):
            data = data.encode('utf-8')
        
        if self.algorithm == 'sha256':
            return hashlib.sha256(data).hexdigest()
        elif self.algorithm == 'sha3_256':
            return hashlib.sha3_256(data).hexdigest()
        elif self.algorithm == 'blake2b':
            return hashlib.blake2b(data).hexdigest()
        else:
            raise ValueError(f"不支持的哈希算法: {self.algorithm}")
    
    def merkle_root(self, leaves):
        """计算Merkle树根"""
        if not leaves:
            return None
        
        # 如果叶子数量为奇数，复制最后一个
        if len(leaves) % 2 == 1:
            leaves.append(leaves[-1])
        
        while len(leaves) > 1:
            next_level = []
            for i in range(0, len(leaves), 2):
                combined = leaves[i] + leaves[i + 1]
                next_level.append(self.hash(combined))
            leaves = next_level
        
        return leaves[0]

# 示例使用
hasher = CryptographicHash('sha256')

# 基本哈希
message = "Hello, ZKP!"
hash_value = hasher.hash(message)
print(f"SHA256('{message}') = {hash_value}")

# Merkle树示例
leaves = ["data1", "data2", "data3", "data4"]
leaf_hashes = [hasher.hash(leaf) for leaf in leaves]
merkle_root = hasher.merkle_root(leaf_hashes)
print(f"Merkle Root = {merkle_root}")
```

## 数学理论

### 1. 生日悖论与碰撞概率

对于输出长度为n位的哈希函数，根据生日悖论：
- 期望碰撞次数：约√(2^n) = 2^(n/2)
- 对于SHA-256 (n=256)：约需要2^128次尝试找到碰撞

### 2. 随机预言机模型

**随机预言机**：理想化的哈希函数，对于每个新的输入返回真正随机的输出。

性质：
- 对于相同输入总是返回相同输出
- 对于不同输入返回独立随机的输出
- 只能通过查询获得输出值

## 代码实现

### ZKP友好哈希函数

```python
class ZKPFriendlyHash:
    """ZKP友好的哈希函数实现"""
    
    def __init__(self, field_prime):
        self.prime = field_prime
    
    def poseidon_hash(self, inputs):
        """Poseidon哈希函数（简化版本）"""
        # 这是一个简化的实现，实际Poseidon需要更复杂的置换
        state = list(inputs) + [0] * (3 - len(inputs) % 3)
        
        # 简化的轮函数
        for round_num in range(8):
            # S-box层（x^5）
            for i in range(len(state)):
                state[i] = pow(state[i], 5, self.prime)
            
            # 线性层（简化的MDS矩阵）
            new_state = [0] * len(state)
            for i in range(len(state)):
                for j in range(len(state)):
                    new_state[i] = (new_state[i] + state[j]) % self.prime
            state = new_state
            
            # 轮常数
            for i in range(len(state)):
                state[i] = (state[i] + round_num + i) % self.prime
        
        return state[0]
    
    def mimc_hash(self, left, right):
        """MiMC哈希函数"""
        # 简化的MiMC实现
        x = (left + right) % self.prime
        
        for round_num in range(220):  # MiMC通常使用220轮
            # S-box: x^3
            x = pow(x, 3, self.prime)
            # 轮常数
            x = (x + round_num) % self.prime
        
        return x

# ZKP友好哈希示例
BN254_PRIME = 21888242871839275222246405745257275088548364400416034343698204186575808495617
zkp_hasher = ZKPFriendlyHash(BN254_PRIME)

# Poseidon哈希
inputs = [123, 456, 789]
poseidon_result = zkp_hasher.poseidon_hash(inputs)
print(f"Poseidon({inputs}) = {poseidon_result}")

# MiMC哈希
mimc_result = zkp_hasher.mimc_hash(123, 456)
print(f"MiMC(123, 456) = {mimc_result}")
```

## ZKP中的应用

### 1. Fiat-Shamir变换

```python
class FiatShamirTransform:
    """Fiat-Shamir变换实现"""
    
    def __init__(self, hasher):
        self.hasher = hasher
    
    def challenge(self, transcript):
        """从交互记录生成挑战"""
        # 将所有交互内容序列化
        serialized = ""
        for item in transcript:
            if isinstance(item, int):
                serialized += str(item)
            elif isinstance(item, str):
                serialized += item
            else:
                serialized += str(item)
        
        # 生成挑战
        hash_output = self.hasher.hash(serialized)
        # 将哈希输出转换为有限域元素
        return int(hash_output, 16) % BN254_PRIME

# 示例：Schnorr签名的非交互版本
fs_transform = FiatShamirTransform(CryptographicHash('sha256'))

# 模拟交互记录
transcript = ["public_key", "commitment", "message"]
challenge = fs_transform.challenge(transcript)
print(f"Fiat-Shamir挑战: {challenge}")
```

### 2. Merkle树在ZKP中的应用

```python
class MerkleProof:
    """Merkle证明系统"""
    
    def __init__(self, hasher):
        self.hasher = hasher
    
    def generate_proof(self, leaves, index):
        """生成Merkle包含证明"""
        if index >= len(leaves):
            raise ValueError("索引超出范围")
        
        proof = []
        current_index = index
        current_level = [self.hasher.hash(leaf) for leaf in leaves]
        
        while len(current_level) > 1:
            # 如果层级大小为奇数，复制最后一个元素
            if len(current_level) % 2 == 1:
                current_level.append(current_level[-1])
            
            # 找到兄弟节点
            if current_index % 2 == 0:
                sibling = current_level[current_index + 1]
                proof.append(('right', sibling))
            else:
                sibling = current_level[current_index - 1]
                proof.append(('left', sibling))
            
            # 移动到下一层
            next_level = []
            for i in range(0, len(current_level), 2):
                combined = current_level[i] + current_level[i + 1]
                next_level.append(self.hasher.hash(combined))
            
            current_level = next_level
            current_index //= 2
        
        return proof, current_level[0]  # 返回证明路径和根
    
    def verify_proof(self, leaf, proof, root):
        """验证Merkle包含证明"""
        current_hash = self.hasher.hash(leaf)
        
        for direction, sibling in proof:
            if direction == 'left':
                combined = sibling + current_hash
            else:
                combined = current_hash + sibling
            current_hash = self.hasher.hash(combined)
        
        return current_hash == root

# Merkle证明示例
merkle_prover = MerkleProof(CryptographicHash('sha256'))

leaves = ["data1", "data2", "data3", "data4"]
proof, root = merkle_prover.generate_proof(leaves, 1)
is_valid = merkle_prover.verify_proof("data2", proof, root)

print(f"Merkle根: {root}")
print(f"证明有效: {is_valid}")
```

## 练习与思考

### 理论练习

1. **碰撞分析**：
   - 计算SHA-256的理论碰撞概率
   - 分析生日攻击的复杂度

2. **安全性证明**：
   - 证明抗碰撞性蕴含抗第二原像性
   - 分析随机预言机模型的局限性

### 编程练习

1. **实现简单哈希函数**：
   ```python
   def simple_hash(data, output_bits=256):
       """实现一个简单的哈希函数"""
       # 练习：实现基于异或和移位的简单哈希
       pass
   ```

2. **Merkle树优化**：
   ```python
   def optimized_merkle_tree(leaves):
       """实现内存优化的Merkle树"""
       # 练习：减少内存使用的Merkle树实现
       pass
   ```

## 参考资料

### 经典教材
- **《Introduction to Modern Cryptography》** - Katz & Lindell
- **《Handbook of Applied Cryptography》** - Menezes, van Oorschot, Vanstone
- **《A Graduate Course in Applied Cryptography》** - Boneh & Shoup

### ZKP相关论文
- **《Fiat-Shamir: From Practice to Theory》** - Canetti et al.
- **《Poseidon: A New Hash Function for Zero-Knowledge Proof Systems》** - Grassi et al.
- **《MiMC: Efficient Encryption and Cryptographic Hashing with Minimal Multiplicative Complexity》** - Albrecht et al.

### 标准文档
- **NIST FIPS 180-4** - Secure Hash Standard (SHS)
- **NIST FIPS 202** - SHA-3 Standard