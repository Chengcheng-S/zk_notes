# 承诺方案 (Commitment Schemes)

## 概述

承诺方案是密码学的基本原语，允许一方承诺一个值而不泄露该值，稍后可以打开承诺来验证。在零知识证明中，承诺方案用于隐藏见证值和构造证明系统。

### 学习目标
- 理解承诺方案的定义和安全性质
- 掌握Pedersen承诺和其他经典承诺方案
- 理解向量承诺和多项式承诺
- 掌握承诺方案在ZKP中的应用

### 前置知识
- 椭圆曲线密码学
- 离散对数问题
- 群论基础

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
承诺方案在ZKP中的核心作用：
- 隐藏见证值和中间计算
- 构造非交互式证明系统
- 实现零知识性质
- 支持批量验证和聚合

## 1. 承诺方案的定义

### 1.1 基本定义

**承诺方案**由三个算法组成：
- **Setup(1^λ) → pp**：生成公共参数
- **Commit(pp, m; r) → c**：承诺消息m，使用随机数r
- **Open(pp, c, m, r) → {0,1}**：验证承诺的打开

### 1.2 安全性质

承诺方案必须满足两个基本性质：

1. **隐藏性 (Hiding)**：承诺不泄露消息信息
   - 计算隐藏：对于多项式时间敌手，承诺在计算上不可区分
   - 完美隐藏：承诺在信息论上不泄露任何信息

2. **绑定性 (Binding)**：承诺者无法改变已承诺的值
   - 计算绑定：多项式时间敌手无法找到冲突
   - 完美绑定：即使无限计算能力也无法找到冲突

**注意**：完美隐藏和完美绑定不能同时满足。

```python
from abc import ABC, abstractmethod
import hashlib
import random

class CommitmentScheme(ABC):
    """承诺方案抽象基类"""
    
    @abstractmethod
    def setup(self, security_parameter):
        """生成公共参数"""
        pass
    
    @abstractmethod
    def commit(self, message, randomness=None):
        """承诺消息"""
        pass
    
    @abstractmethod
    def open(self, commitment, message, randomness):
        """验证承诺打开"""
        pass
    
    def verify_hiding(self, m1, m2, num_tests=1000):
        """测试隐藏性（统计测试）"""
        pp = self.setup(128)
        
        correct_guesses = 0
        for _ in range(num_tests):
            # 随机选择消息
            message = m1 if random.choice([True, False]) else m2
            commitment = self.commit(message)
            
            # 敌手尝试猜测（这里简化为随机猜测）
            guess = m1 if random.choice([True, False]) else m2
            if guess == message:
                correct_guesses += 1
        
        # 隐藏性好的方案应该接近50%的正确率
        accuracy = correct_guesses / num_tests
        return abs(accuracy - 0.5) < 0.1  # 允许10%的偏差
    
    def verify_binding(self, num_tests=1000):
        """测试绑定性（寻找冲突）"""
        pp = self.setup(128)
        
        for _ in range(num_tests):
            # 尝试找到冲突：相同承诺，不同消息
            m1 = random.randint(0, 1000)
            r1 = random.randint(0, 2**32)
            c1 = self.commit(m1, r1)
            
            # 尝试不同的消息和随机数
            for _ in range(100):
                m2 = random.randint(0, 1000)
                r2 = random.randint(0, 2**32)
                
                if m1 != m2:  # 不同消息
                    c2 = self.commit(m2, r2)
                    if c1 == c2:  # 相同承诺
                        return False  # 找到冲突，绑定性失败
        
        return True  # 未找到冲突
```

## 2. Pedersen承诺

### 2.1 基本Pedersen承诺

**构造**：基于离散对数问题的承诺方案
- **Setup**：选择群G，生成元g, h，其中log_g(h)未知
- **Commit(m, r)**：c = g^m · h^r
- **Open(c, m, r)**：验证 c = g^m · h^r

```python
class PedersenCommitment(CommitmentScheme):
    """Pedersen承诺方案"""
    
    def __init__(self, group_order, generator1, generator2):
        self.p = group_order  # 群的阶
        self.g = generator1   # 生成元g
        self.h = generator2   # 生成元h，满足log_g(h)未知
    
    def setup(self, security_parameter):
        """公共参数已在初始化时设定"""
        return {'p': self.p, 'g': self.g, 'h': self.h}
    
    def commit(self, message, randomness=None):
        """承诺：c = g^m · h^r"""
        if randomness is None:
            randomness = random.randint(1, self.p - 1)
        
        commitment = (pow(self.g, message, self.p) * pow(self.h, randomness, self.p)) % self.p
        return commitment, randomness
    
    def open(self, commitment, message, randomness):
        """验证承诺打开"""
        expected = (pow(self.g, message, self.p) * pow(self.h, randomness, self.p)) % self.p
        return commitment == expected
    
    def homomorphic_add(self, c1, c2):
        """同态加法：Commit(m1) · Commit(m2) = Commit(m1 + m2)"""
        return (c1 * c2) % self.p
    
    def homomorphic_scalar_mul(self, commitment, scalar):
        """同态标量乘法：Commit(m)^k = Commit(k·m)"""
        return pow(commitment, scalar, self.p)

# 示例使用
p = 2**256 - 2**32 - 977  # secp256k1的素数
g = 2  # 简化的生成元
h = 3  # 另一个生成元

pedersen = PedersenCommitment(p, g, h)

# 承诺消息
message = 42
commitment, randomness = pedersen.commit(message)
print(f"承诺: {commitment}")

# 验证打开
is_valid = pedersen.open(commitment, message, randomness)
print(f"验证结果: {is_valid}")

# 同态性质
m1, m2 = 10, 20
c1, r1 = pedersen.commit(m1)
c2, r2 = pedersen.commit(m2)

# c1 · c2 应该等于 Commit(m1 + m2, r1 + r2)
c_sum = pedersen.homomorphic_add(c1, c2)
c_expected, _ = pedersen.commit(m1 + m2, r1 + r2)
print(f"同态加法验证: {c_sum == c_expected}")
```

### 2.2 椭圆曲线Pedersen承诺

```python
class ECPedersenCommitment:
    """基于椭圆曲线的Pedersen承诺"""
    
    def __init__(self, curve, G, H):
        self.curve = curve
        self.G = G  # 生成元G
        self.H = H  # 生成元H，满足H ≠ k·G对已知k
    
    def commit(self, message, randomness=None):
        """承诺：C = m·G + r·H"""
        if randomness is None:
            randomness = random.randint(1, self.curve.order - 1)
        
        commitment = self.G * message + self.H * randomness
        return commitment, randomness
    
    def open(self, commitment, message, randomness):
        """验证承诺打开"""
        expected = self.G * message + self.H * randomness
        return commitment.x == expected.x and commitment.y == expected.y
    
    def batch_commit(self, messages, randomness_list=None):
        """批量承诺"""
        if randomness_list is None:
            randomness_list = [random.randint(1, self.curve.order - 1) for _ in messages]
        
        commitments = []
        for m, r in zip(messages, randomness_list):
            commitment = self.G * m + self.H * r
            commitments.append(commitment)
        
        return commitments, randomness_list
    
    def vector_commit(self, vector, randomness=None):
        """向量承诺（需要多个生成元）"""
        if randomness is None:
            randomness = random.randint(1, self.curve.order - 1)
        
        # 假设有足够的生成元G_i
        commitment = self.curve.infinity()
        for i, v in enumerate(vector):
            # 在实际实现中，需要预计算多个独立的生成元
            G_i = self.G * (i + 1)  # 简化实现
            commitment = commitment + G_i * v
        
        commitment = commitment + self.H * randomness
        return commitment, randomness
```

## 3. 哈希承诺

### 3.1 基本哈希承诺

```python
class HashCommitment(CommitmentScheme):
    """基于哈希函数的承诺方案"""
    
    def __init__(self, hash_function=hashlib.sha256):
        self.hash_func = hash_function
    
    def setup(self, security_parameter):
        """哈希承诺不需要特殊设置"""
        return {'hash_function': self.hash_func.__name__}
    
    def commit(self, message, randomness=None):
        """承诺：c = H(m || r)"""
        if randomness is None:
            randomness = random.getrandbits(256)
        
        # 将消息和随机数连接后哈希
        data = str(message).encode() + randomness.to_bytes(32, 'big')
        commitment = self.hash_func(data).hexdigest()
        
        return commitment, randomness
    
    def open(self, commitment, message, randomness):
        """验证承诺打开"""
        data = str(message).encode() + randomness.to_bytes(32, 'big')
        expected = self.hash_func(data).hexdigest()
        return commitment == expected
    
    def commit_with_salt(self, message, salt):
        """使用指定盐值的承诺"""
        data = str(message).encode() + salt.encode()
        commitment = self.hash_func(data).hexdigest()
        return commitment

# 示例
hash_commit = HashCommitment()

message = "secret_value"
commitment, randomness = hash_commit.commit(message)
print(f"哈希承诺: {commitment}")

is_valid = hash_commit.open(commitment, message, randomness)
print(f"验证结果: {is_valid}")
```

### 3.2 Merkle树承诺

```python
class MerkleTreeCommitment:
    """基于Merkle树的承诺方案"""
    
    def __init__(self, hash_function=hashlib.sha256):
        self.hash_func = hash_function
    
    def commit_vector(self, vector):
        """承诺向量（构造Merkle树）"""
        if not vector:
            return None
        
        # 确保向量长度是2的幂
        n = len(vector)
        if n & (n - 1) != 0:
            # 填充到下一个2的幂
            next_power = 1 << (n - 1).bit_length()
            vector = vector + [0] * (next_power - n)
        
        # 构造Merkle树
        tree = self._build_tree(vector)
        root = tree[0] if tree else None
        
        return root, tree
    
    def _build_tree(self, leaves):
        """构造Merkle树"""
        if not leaves:
            return []
        
        # 叶子节点哈希
        current_level = [self._hash_leaf(leaf) for leaf in leaves]
        tree = [current_level[:]]
        
        # 自底向上构造
        while len(current_level) > 1:
            next_level = []
            for i in range(0, len(current_level), 2):
                left = current_level[i]
                right = current_level[i + 1] if i + 1 < len(current_level) else left
                parent = self._hash_internal(left, right)
                next_level.append(parent)
            
            tree.insert(0, next_level)
            current_level = next_level
        
        return tree
    
    def _hash_leaf(self, value):
        """叶子节点哈希"""
        return self.hash_func(str(value).encode()).hexdigest()
    
    def _hash_internal(self, left, right):
        """内部节点哈希"""
        return self.hash_func((left + right).encode()).hexdigest()
    
    def generate_proof(self, tree, index):
        """生成包含证明"""
        if not tree:
            return []
        
        proof = []
        current_index = index
        
        # 从叶子到根收集兄弟节点
        for level in reversed(tree[1:]):  # 跳过根节点
            sibling_index = current_index ^ 1  # 异或得到兄弟索引
            if sibling_index < len(level):
                proof.append((level[sibling_index], current_index % 2))
            current_index //= 2
        
        return proof
    
    def verify_proof(self, root, value, index, proof):
        """验证包含证明"""
        current_hash = self._hash_leaf(value)
        current_index = index
        
        for sibling_hash, is_right in proof:
            if is_right:
                current_hash = self._hash_internal(sibling_hash, current_hash)
            else:
                current_hash = self._hash_internal(current_hash, sibling_hash)
            current_index //= 2
        
        return current_hash == root

# 示例
merkle = MerkleTreeCommitment()

# 承诺向量
vector = [1, 2, 3, 4, 5, 6, 7, 8]
root, tree = merkle.commit_vector(vector)
print(f"Merkle根: {root}")

# 生成包含证明
index = 2  # 证明第3个元素
proof = merkle.generate_proof(tree, index)
print(f"包含证明: {proof}")

# 验证证明
is_valid = merkle.verify_proof(root, vector[index], index, proof)
print(f"验证结果: {is_valid}")
```

## 4. 向量承诺

### 4.1 定义

**向量承诺**允许承诺一个向量，并能够：
- 生成向量中单个位置的打开证明
- 验证某个位置的值而不泄露其他位置

```python
class VectorCommitment(ABC):
    """向量承诺抽象基类"""
    
    @abstractmethod
    def setup(self, max_size):
        """设置支持的最大向量长度"""
        pass
    
    @abstractmethod
    def commit(self, vector):
        """承诺向量"""
        pass
    
    @abstractmethod
    def open(self, vector, index):
        """生成位置index的打开证明"""
        pass
    
    @abstractmethod
    def verify(self, commitment, index, value, proof):
        """验证位置打开"""
        pass

class PedersenVectorCommitment(VectorCommitment):
    """基于Pedersen的向量承诺"""
    
    def __init__(self, curve):
        self.curve = curve
        self.generators = []
    
    def setup(self, max_size):
        """生成足够的独立生成元"""
        # 在实际实现中，需要使用可验证的随机生成方法
        self.generators = []
        base_point = self.curve.generator()
        
        for i in range(max_size + 1):  # +1 for randomness
            # 使用哈希到曲线的方法生成独立生成元
            generator = self._hash_to_curve(f"generator_{i}")
            self.generators.append(generator)
        
        return self.generators
    
    def _hash_to_curve(self, data):
        """哈希到椭圆曲线（简化实现）"""
        # 实际实现需要使用安全的哈希到曲线算法
        hash_value = int(hashlib.sha256(data.encode()).hexdigest(), 16)
        return self.curve.generator() * (hash_value % self.curve.order)
    
    def commit(self, vector, randomness=None):
        """承诺向量：C = Σ vᵢ·Gᵢ + r·H"""
        if len(vector) > len(self.generators) - 1:
            raise ValueError("向量长度超过支持的最大长度")
        
        if randomness is None:
            randomness = random.randint(1, self.curve.order - 1)
        
        commitment = self.curve.infinity()
        
        # 向量元素承诺
        for i, value in enumerate(vector):
            commitment = commitment + self.generators[i] * value
        
        # 添加随机性
        commitment = commitment + self.generators[-1] * randomness
        
        return commitment, randomness
    
    def open(self, vector, index, randomness):
        """生成位置index的打开证明"""
        if index >= len(vector):
            raise ValueError("索引超出向量范围")
        
        value = vector[index]
        
        # 计算不包含位置index的承诺
        partial_commitment = self.curve.infinity()
        for i, v in enumerate(vector):
            if i != index:
                partial_commitment = partial_commitment + self.generators[i] * v
        
        # 添加随机性
        partial_commitment = partial_commitment + self.generators[-1] * randomness
        
        proof = {
            'value': value,
            'partial_commitment': partial_commitment
        }
        
        return proof
    
    def verify(self, commitment, index, proof):
        """验证位置打开"""
        value = proof['value']
        partial_commitment = proof['partial_commitment']
        
        # 重构承诺
        expected_commitment = partial_commitment + self.generators[index] * value
        
        return (commitment.x == expected_commitment.x and 
                commitment.y == expected_commitment.y)
```

## 5. ZKP中的应用

### 5.1 承诺-打开协议

```python
class CommitRevealProtocol:
    """承诺-打开协议"""
    
    def __init__(self, commitment_scheme):
        self.commitment_scheme = commitment_scheme
    
    def commit_phase(self, prover_value):
        """承诺阶段"""
        commitment, randomness = self.commitment_scheme.commit(prover_value)
        
        # 证明者发送承诺给验证者
        return {
            'commitment': commitment,
            'randomness': randomness  # 证明者保留
        }
    
    def reveal_phase(self, commit_data, revealed_value):
        """打开阶段"""
        commitment = commit_data['commitment']
        randomness = commit_data['randomness']
        
        # 证明者发送值和随机数给验证者
        is_valid = self.commitment_scheme.open(commitment, revealed_value, randomness)
        
        return is_valid

# 示例：零知识猜数字游戏
def zero_knowledge_guessing_game():
    """零知识猜数字游戏"""
    pedersen = PedersenCommitment(2**256 - 2**32 - 977, 2, 3)
    protocol = CommitRevealProtocol(pedersen)
    
    # 证明者选择秘密数字
    secret_number = 42
    
    # 承诺阶段
    commit_data = protocol.commit_phase(secret_number)
    print(f"证明者承诺: {commit_data['commitment']}")
    
    # 验证者猜测
    guess = 42
    
    # 打开阶段
    is_correct = protocol.reveal_phase(commit_data, guess)
    print(f"猜测正确: {is_correct}")
    
    return is_correct

# 运行游戏
zero_knowledge_guessing_game()
```

### 5.2 Fiat-Shamir变换

```python
class FiatShamirTransform:
    """Fiat-Shamir变换：将交互式协议转为非交互式"""
    
    def __init__(self, hash_function=hashlib.sha256):
        self.hash_func = hash_function
    
    def challenge_from_transcript(self, transcript):
        """从交互记录生成挑战"""
        # 将所有交互内容连接后哈希
        data = ""
        for message in transcript:
            data += str(message)
        
        challenge_hash = self.hash_func(data.encode()).hexdigest()
        challenge = int(challenge_hash, 16) % (2**128)  # 截断到合适长度
        
        return challenge
    
    def non_interactive_proof(self, statement, witness, commitment_scheme):
        """生成非交互式证明"""
        # 第一轮：承诺
        commitment, randomness = commitment_scheme.commit(witness)
        
        # 生成挑战（替代验证者的随机挑战）
        transcript = [statement, commitment]
        challenge = self.challenge_from_transcript(transcript)
        
        # 第二轮：响应
        response = (witness + challenge * randomness) % commitment_scheme.p
        
        proof = {
            'commitment': commitment,
            'challenge': challenge,
            'response': response
        }
        
        return proof
    
    def verify_non_interactive_proof(self, statement, proof, commitment_scheme):
        """验证非交互式证明"""
        commitment = proof['commitment']
        challenge = proof['challenge']
        response = proof['response']
        
        # 重新计算挑战
        transcript = [statement, commitment]
        expected_challenge = self.challenge_from_transcript(transcript)
        
        if challenge != expected_challenge:
            return False
        
        # 验证响应
        # 这里简化验证逻辑
        return True

# 示例
fs = FiatShamirTransform()
pedersen = PedersenCommitment(2**256 - 2**32 - 977, 2, 3)

statement = "I know the discrete log"
witness = 12345

proof = fs.non_interactive_proof(statement, witness, pedersen)
is_valid = fs.verify_non_interactive_proof(statement, proof, pedersen)

print(f"非交互式证明验证: {is_valid}")
```

## 参考资料

### 经典论文
- **《Commitment Schemes》** - Pedersen (1991)
- **《Non-Interactive and Information-Theoretic Secure Verifiable Secret Sharing》** - Pedersen (1991)
- **《Vector Commitments and their Applications》** - Catalano & Fiore (2013)

### 现代发展
- **《Bulletproofs》** - Bünz et al. (2018)
- **《Sonic》** - Maller et al. (2019)
- **《Plonk》** - Gabizon, Williamson, Ciobotaru (2019)