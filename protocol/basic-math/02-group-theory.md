# 群论基础 (Group Theory Fundamentals)

## 概述

群论是抽象代数的核心分支，为密码学和零知识证明提供了重要的数学框架。本章涵盖群、环、域的基本概念及其在ZKP中的应用。

### 学习目标
- 理解群、环、域的定义和基本性质
- 掌握循环群和有限群的重要性质
- 理解群同态和同构的概念
- 掌握拉格朗日定理和相关应用

### 前置知识
- 集合论基础
- 基本代数运算

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
群论是密码学的数学基础：
- 椭圆曲线群用于数字签名和承诺
- 有限域的乘法群支持多项式运算
- 循环群性质保证密码学安全性
- 群同态用于零知识证明构造

## 1. 群的基本概念

### 1.1 群的定义

**群 (Group)**：一个群是一个集合 G 配备一个二元运算 ∘，满足以下四个公理：

1. **封闭性**：∀a, b ∈ G, a ∘ b ∈ G
2. **结合律**：∀a, b, c ∈ G, (a ∘ b) ∘ c = a ∘ (b ∘ c)
3. **单位元**：∃e ∈ G, ∀a ∈ G, e ∘ a = a ∘ e = a
4. **逆元**：∀a ∈ G, ∃a⁻¹ ∈ G, a ∘ a⁻¹ = a⁻¹ ∘ a = e

### 1.2 群的阶

**群的阶**：群 G 中元素的个数，记作 |G|。
- 有限群：|G| < ∞
- 无限群：|G| = ∞

**元素的阶**：元素 a 的阶是使得 aⁿ = e 的最小正整数 n，记作 ord(a)。

### 1.3 重要性质

1. **单位元唯一性**：群中的单位元是唯一的
2. **逆元唯一性**：每个元素的逆元是唯一的
3. **消去律**：如果 ab = ac，则 b = c

```python
class Group:
    """抽象群的基本实现"""
    
    def __init__(self, elements, operation, identity):
        self.elements = set(elements)
        self.operation = operation
        self.identity = identity
        self._verify_group_axioms()
    
    def _verify_group_axioms(self):
        """验证群公理"""
        # 验证封闭性
        for a in self.elements:
            for b in self.elements:
                result = self.operation(a, b)
                assert result in self.elements, "封闭性不满足"
        
        # 验证结合律（简化验证）
        # 验证单位元
        for a in self.elements:
            assert self.operation(self.identity, a) == a
            assert self.operation(a, self.identity) == a
    
    def order(self):
        """返回群的阶"""
        return len(self.elements)
    
    def element_order(self, element):
        """计算元素的阶"""
        current = element
        order = 1
        while current != self.identity:
            current = self.operation(current, element)
            order += 1
            if order > len(self.elements):
                return float('inf')  # 无限阶
        return order
```

## 2. 特殊类型的群

### 2.1 阿贝尔群 (Abelian Group)

**定义**：满足交换律的群，即 ∀a, b ∈ G, a ∘ b = b ∘ a。

**重要性**：
- 大多数密码学应用中使用的群都是阿贝尔群
- 椭圆曲线群、有限域的乘法群都是阿贝尔群

### 2.2 循环群 (Cyclic Group)

**定义**：由单个元素生成的群。如果群 G 中存在元素 g，使得 G = {gⁿ | n ∈ ℤ}，则称 G 为循环群，g 为生成元。

**性质**：
1. 所有循环群都是阿贝尔群
2. 有限循环群 G 的每个子群也是循环群
3. 阶为素数的群必定是循环群

```python
class CyclicGroup(Group):
    """循环群的实现"""
    
    def __init__(self, generator, order, operation):
        self.generator = generator
        self.group_order = order
        # 生成所有元素
        elements = []
        current = generator
        for i in range(order):
            elements.append(current)
            if i < order - 1:
                current = operation(current, generator)
        
        # 确定单位元（应该是最后一个元素的运算结果）
        identity = operation(elements[-1], generator)
        
        super().__init__(elements, operation, identity)
    
    def is_generator(self, element):
        """检查元素是否为生成元"""
        return self.element_order(element) == self.group_order
    
    def find_generators(self):
        """找到所有生成元"""
        generators = []
        for element in self.elements:
            if self.is_generator(element):
                generators.append(element)
        return generators
```

### 2.3 子群 (Subgroup)

**定义**：群 G 的子集 H，如果 H 在 G 的运算下也构成群，则称 H 为 G 的子群。

**拉格朗日定理**：有限群 G 的任意子群 H 的阶都整除 G 的阶。

```python
def find_subgroups(group):
    """找到群的所有子群"""
    subgroups = []
    n = group.order()
    
    # 检查所有可能的子群大小（必须整除群的阶）
    for size in range(1, n + 1):
        if n % size == 0:
            # 尝试找到该大小的子群
            for element in group.elements:
                subgroup_elements = generate_subgroup(group, element)
                if len(subgroup_elements) == size:
                    subgroups.append(subgroup_elements)
    
    return subgroups

def generate_subgroup(group, generator):
    """由单个元素生成子群"""
    subgroup = {group.identity}
    current = generator
    
    while current not in subgroup:
        subgroup.add(current)
        current = group.operation(current, generator)
    
    return subgroup
```

## 3. 重要的群例子

### 3.1 整数加法群 (ℤ, +)

- **元素**：所有整数
- **运算**：普通加法
- **单位元**：0
- **逆元**：a 的逆元是 -a
- **性质**：无限循环群，生成元为 1 或 -1

### 3.2 模 n 整数加法群 (ℤₙ, +)

```python
class ModularAdditionGroup:
    """模 n 整数加法群"""
    
    def __init__(self, n):
        self.n = n
        self.elements = list(range(n))
        self.identity = 0
    
    def add(self, a, b):
        """模 n 加法"""
        return (a + b) % self.n
    
    def inverse(self, a):
        """加法逆元"""
        return (-a) % self.n
    
    def order(self):
        return self.n
    
    def element_order(self, a):
        """元素的阶"""
        if a == 0:
            return 1
        return self.n // gcd(a, self.n)
```

### 3.3 模 p 非零整数乘法群 (ℤₚ*, ×)

```python
class ModularMultiplicationGroup:
    """模素数 p 的乘法群"""
    
    def __init__(self, p):
        assert is_prime(p), "p 必须是素数"
        self.p = p
        self.elements = list(range(1, p))  # 不包含 0
        self.identity = 1
    
    def multiply(self, a, b):
        """模 p 乘法"""
        return (a * b) % self.p
    
    def inverse(self, a):
        """乘法逆元"""
        return mod_inverse(a, self.p)
    
    def order(self):
        return self.p - 1
    
    def is_primitive_root(self, g):
        """检查 g 是否为原根（生成元）"""
        return self.element_order(g) == self.p - 1
    
    def find_primitive_roots(self):
        """找到所有原根"""
        roots = []
        for g in self.elements:
            if self.is_primitive_root(g):
                roots.append(g)
        return roots
```

## 4. 群同态与同构

### 4.1 群同态 (Group Homomorphism)

**定义**：设 (G, ∘) 和 (H, *) 是两个群，映射 φ: G → H 称为群同态，如果：
$$φ(a ∘ b) = φ(a) * φ(b), \quad ∀a, b ∈ G$$

**重要性质**：
1. φ(eG) = eH（单位元映射到单位元）
2. φ(a⁻¹) = φ(a)⁻¹（逆元的像是像的逆元）

### 4.2 群同构 (Group Isomorphism)

**定义**：双射的群同态称为群同构。同构的群在群论意义下是"相同"的。

```python
def is_isomorphic(group1, group2):
    """检查两个群是否同构（简化版本）"""
    # 首先检查阶是否相同
    if group1.order() != group2.order():
        return False
    
    # 检查元素阶的分布是否相同
    orders1 = [group1.element_order(e) for e in group1.elements]
    orders2 = [group2.element_order(e) for e in group2.elements]
    
    from collections import Counter
    return Counter(orders1) == Counter(orders2)
```

## 5. 椭圆曲线群

### 5.1 椭圆曲线上的群结构

椭圆曲线 E: y² = x³ + ax + b 上的点形成一个阿贝尔群：

**群运算**：几何上的"弦切法则"
- **单位元**：无穷远点 O
- **逆元**：点 (x, y) 的逆元是 (x, -y)
- **加法**：通过几何构造定义

```python
class EllipticCurvePoint:
    """椭圆曲线上的点"""
    
    def __init__(self, x, y, curve):
        self.x = x
        self.y = y
        self.curve = curve
        self.is_infinity = (x is None and y is None)
    
    def __add__(self, other):
        """椭圆曲线点加法"""
        if self.is_infinity:
            return other
        if other.is_infinity:
            return self
        
        if self.x == other.x:
            if self.y == other.y:
                # 点倍加
                return self._point_double()
            else:
                # 互为逆元
                return EllipticCurvePoint(None, None, self.curve)
        
        # 一般情况的点加法
        return self._point_add(other)
    
    def _point_double(self):
        """点倍加"""
        if self.is_infinity:
            return self
        
        # 计算切线斜率
        s = (3 * self.x * self.x + self.curve.a) * mod_inverse(2 * self.y, self.curve.p)
        s %= self.curve.p
        
        # 计算新点坐标
        x3 = (s * s - 2 * self.x) % self.curve.p
        y3 = (s * (self.x - x3) - self.y) % self.curve.p
        
        return EllipticCurvePoint(x3, y3, self.curve)
    
    def _point_add(self, other):
        """两个不同点的加法"""
        # 计算直线斜率
        dx = (other.x - self.x) % self.curve.p
        dy = (other.y - self.y) % self.curve.p
        s = (dy * mod_inverse(dx, self.curve.p)) % self.curve.p
        
        # 计算新点坐标
        x3 = (s * s - self.x - other.x) % self.curve.p
        y3 = (s * (self.x - x3) - self.y) % self.curve.p
        
        return EllipticCurvePoint(x3, y3, self.curve)
    
    def __mul__(self, scalar):
        """标量乘法（重复加法）"""
        if scalar == 0:
            return EllipticCurvePoint(None, None, self.curve)
        
        result = EllipticCurvePoint(None, None, self.curve)  # 无穷远点
        addend = self
        
        while scalar > 0:
            if scalar & 1:
                result = result + addend
            addend = addend + addend
            scalar >>= 1
        
        return result
```

### 5.2 椭圆曲线的阶

**Hasse定理**：椭圆曲线 E 在有限域 𝔽p 上的点数 #E(𝔽p) 满足：
$$|p + 1 - \#E(\mathbb{F}_p)| \leq 2\sqrt{p}$$

## 6. 在密码学中的应用

### 6.1 离散对数问题

在循环群 G 中，给定 g 和 h = gˣ，求解 x 的问题称为离散对数问题（DLP）。

**安全性**：许多密码系统的安全性基于 DLP 的困难性：
- ElGamal 加密
- Schnorr 签名
- Pedersen 承诺

### 6.2 Diffie-Hellman 问题

**计算 Diffie-Hellman 问题 (CDH)**：给定 g, gᵃ, gᵇ，计算 gᵃᵇ。

**判定 Diffie-Hellman 问题 (DDH)**：给定 g, gᵃ, gᵇ, gᶜ，判断是否 c = ab。

```python
class DiffieHellmanGroup:
    """Diffie-Hellman 密钥交换群"""
    
    def __init__(self, p, g):
        self.p = p  # 大素数
        self.g = g  # 生成元
    
    def generate_private_key(self):
        """生成私钥"""
        return random.randrange(1, self.p - 1)
    
    def compute_public_key(self, private_key):
        """计算公钥"""
        return fast_power(self.g, private_key, self.p)
    
    def compute_shared_secret(self, private_key, other_public_key):
        """计算共享密钥"""
        return fast_power(other_public_key, private_key, self.p)
```

## 7. 群在零知识证明中的作用

### 7.1 承诺方案

**Pedersen 承诺**：基于离散对数问题的承诺方案
- 群：循环群 G，生成元 g, h
- 承诺：Com(m, r) = gᵐhʳ
- 性质：完美隐藏性、计算绑定性

### 7.2 数字签名

**Schnorr 签名**：
1. 私钥：x ∈ ℤq
2. 公钥：y = gˣ
3. 签名：(R, s) 其中 R = gʳ, s = r + cx
4. 验证：gˢ = R · yᶜ

### 7.3 双线性映射

**双线性群**：三个群 G₁, G₂, GT 和双线性映射 e: G₁ × G₂ → GT
- 应用：BLS 签名、配对友好的椭圆曲线
- 性质：e(gᵃ, hᵇ) = e(g, h)ᵃᵇ

## 8. 练习与应用

### 8.1 编程练习

1. 实现模 p 乘法群并找到所有原根
2. 实现椭圆曲线点运算并验证群公理
3. 构造简单的 Diffie-Hellman 密钥交换
4. 实现 Pedersen 承诺方案

### 8.2 理论练习

1. 证明所有阶为素数的群都是循环群
2. 分析椭圆曲线群的安全性参数选择
3. 研究不同群结构对密码协议安全性的影响

