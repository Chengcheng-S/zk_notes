# 多项式理论 (Polynomial Theory)

## 概述

多项式理论是零知识证明的数学核心，几乎所有的ZKP协议都基于多项式运算。本章涵盖多项式的基本理论、插值方法、快速变换算法等。

### 学习目标
- 掌握多项式的基本概念和运算
- 理解拉格朗日插值和其他插值方法
- 掌握FFT和NTT的原理与应用
- 理解多项式在ZKP中的核心作用

### 前置知识
- 有限域理论
- 群论基础（循环群、单位根）
- 线性代数基础

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
多项式是ZKP的核心工具：
- 电路约束表示为多项式
- 证明和验证基于多项式运算
- 多项式承诺是现代ZKP的基础
- FFT使大规模计算成为可能

## 1. 多项式基础

### 1.1 多项式的定义

**多项式**：设 F 是一个域，F 上的一元多项式是形如：
$$P(x) = a_n x^n + a_{n-1} x^{n-1} + \cdots + a_1 x + a_0$$
的表达式，其中 $a_i \in F$，$a_n \neq 0$。

- **度数 (Degree)**：最高次项的次数，记作 $\deg(P)$
- **首项系数 (Leading Coefficient)**：最高次项的系数 $a_n$
- **多项式环**：F 上所有多项式构成环 F[x]

### 1.2 多项式的表示

多项式有两种主要表示方法：

1. **系数表示 (Coefficient Form)**：
   $$P(x) = \sum_{i=0}^{n} a_i x^i$$

2. **点值表示 (Point-Value Form)**：
   $$P(x) \leftrightarrow \{(x_0, P(x_0)), (x_1, P(x_1)), \ldots, (x_n, P(x_n))\}$$

```python
class Polynomial:
    """有限域上的多项式"""
    
    def __init__(self, coefficients, field_prime):
        # 移除前导零
        while len(coefficients) > 1 and coefficients[-1] == 0:
            coefficients.pop()
        self.coefficients = [c % field_prime for c in coefficients]
        self.prime = field_prime
    
    def degree(self):
        return len(self.coefficients) - 1 if self.coefficients else -1
    
    def evaluate(self, x):
        """霍纳方法求值"""
        if not self.coefficients:
            return 0
        
        result = self.coefficients[-1]
        for i in range(len(self.coefficients) - 2, -1, -1):
            result = (result * x + self.coefficients[i]) % self.prime
        return result
    
    def __add__(self, other):
        max_len = max(len(self.coefficients), len(other.coefficients))
        result = []
        for i in range(max_len):
            a = self.coefficients[i] if i < len(self.coefficients) else 0
            b = other.coefficients[i] if i < len(other.coefficients) else 0
            result.append((a + b) % self.prime)
        return Polynomial(result, self.prime)
    
    def __mul__(self, other):
        if not self.coefficients or not other.coefficients:
            return Polynomial([0], self.prime)
        
        result = [0] * (len(self.coefficients) + len(other.coefficients) - 1)
        for i, a in enumerate(self.coefficients):
            for j, b in enumerate(other.coefficients):
                result[i + j] = (result[i + j] + a * b) % self.prime
        
        return Polynomial(result, self.prime)

# 示例
p = 17  # 素数
poly1 = Polynomial([1, 2, 3], p)  # 3x² + 2x + 1
poly2 = Polynomial([4, 5], p)     # 5x + 4

print(f"P₁(2) = {poly1.evaluate(2)}")  # 计算 P₁(2)
sum_poly = poly1 + poly2
print(f"P₁ + P₂ = {sum_poly.coefficients}")
```

## 2. 拉格朗日插值

### 2.1 插值问题

**插值问题**：给定 n+1 个不同的点 $(x_0, y_0), (x_1, y_1), \ldots, (x_n, y_n)$，求度数不超过 n 的多项式 P(x)，使得 $P(x_i) = y_i$。

**唯一性定理**：满足插值条件的度数不超过 n 的多项式是唯一的。

### 2.2 拉格朗日插值公式

**拉格朗日基多项式**：
$$L_i(x) = \prod_{j=0, j \neq i}^{n} \frac{x - x_j}{x_i - x_j}$$

**拉格朗日插值多项式**：
$$P(x) = \sum_{i=0}^{n} y_i L_i(x)$$

```python
def lagrange_interpolation(points, field_prime):
    """拉格朗日插值"""
    n = len(points)
    x_coords = [p[0] for p in points]
    y_coords = [p[1] for p in points]
    
    # 构造插值多项式
    result_coeffs = [0] * n
    
    for i in range(n):
        # 构造第 i 个拉格朗日基多项式
        li_coeffs = [1]  # 从常数项 1 开始
        
        for j in range(n):
            if i != j:
                # 乘以 (x - x_j) / (x_i - x_j)
                denominator = (x_coords[i] - x_coords[j]) % field_prime
                denominator_inv = pow(denominator, field_prime - 2, field_prime)
                
                # 乘以 (x - x_j)
                new_coeffs = [0] * (len(li_coeffs) + 1)
                for k in range(len(li_coeffs)):
                    new_coeffs[k] = (new_coeffs[k] - li_coeffs[k] * x_coords[j]) % field_prime
                    new_coeffs[k + 1] = (new_coeffs[k + 1] + li_coeffs[k]) % field_prime
                
                # 除以 (x_i - x_j)
                li_coeffs = [(c * denominator_inv) % field_prime for c in new_coeffs]
        
        # 乘以 y_i 并加到结果中
        for k in range(len(li_coeffs)):
            if k < len(result_coeffs):
                result_coeffs[k] = (result_coeffs[k] + y_coords[i] * li_coeffs[k]) % field_prime
            else:
                result_coeffs.append((y_coords[i] * li_coeffs[k]) % field_prime)
    
    return Polynomial(result_coeffs, field_prime)

# 示例：插值三个点
points = [(1, 2), (2, 5), (3, 10)]  # 对应 y = x² + 1
p = 17
interpolated = lagrange_interpolation(points, p)
print(f"插值多项式系数: {interpolated.coefficients}")

# 验证
for x, y in points:
    assert interpolated.evaluate(x) == y
print("插值验证通过")
```

## 3. 快速傅里叶变换 (FFT)

### 3.1 离散傅里叶变换 (DFT)

**定义**：对于长度为 n 的序列 $a = (a_0, a_1, \ldots, a_{n-1})$，其DFT为：
$$\hat{a}_k = \sum_{j=0}^{n-1} a_j \omega_n^{jk}$$
其中 $\omega_n$ 是 n 次单位根。

**逆DFT**：
$$a_j = \frac{1}{n} \sum_{k=0}^{n-1} \hat{a}_k \omega_n^{-jk}$$

### 3.2 数论变换 (NTT)

在有限域中，我们使用数论变换代替FFT：

```python
def find_primitive_root_of_unity(n, prime):
    """寻找 n 次本原单位根"""
    # 要求 prime - 1 能被 n 整除
    if (prime - 1) % n != 0:
        raise ValueError(f"素数 {prime} 不支持 {n} 点 NTT")
    
    # 寻找本原根
    for g in range(2, prime):
        if pow(g, (prime - 1) // n, prime) != 1:
            continue
        
        # 检查是否为 n 次本原单位根
        omega = pow(g, (prime - 1) // n, prime)
        if pow(omega, n, prime) == 1:
            # 验证是本原的
            is_primitive = True
            for i in range(1, n):
                if pow(omega, i, prime) == 1:
                    is_primitive = False
                    break
            if is_primitive:
                return omega
    
    raise ValueError(f"未找到 {n} 次本原单位根")

def ntt(a, prime, inverse=False):
    """数论变换 (Number Theoretic Transform)"""
    n = len(a)
    if n == 1:
        return a[:]
    
    # 确保 n 是 2 的幂
    if n & (n - 1) != 0:
        raise ValueError("NTT 要求长度为 2 的幂")
    
    # 寻找本原单位根
    omega = find_primitive_root_of_unity(n, prime)
    if inverse:
        omega = pow(omega, prime - 2, prime)  # 逆元
    
    # 位反转置换
    result = a[:]
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit
            bit >>= 1
        j ^= bit
        if i < j:
            result[i], result[j] = result[j], result[i]
    
    # Cooley-Tukey FFT
    length = 2
    while length <= n:
        w = pow(omega, n // length, prime)
        for i in range(0, n, length):
            wn = 1
            for j in range(length // 2):
                u = result[i + j]
                v = (result[i + j + length // 2] * wn) % prime
                result[i + j] = (u + v) % prime
                result[i + j + length // 2] = (u - v) % prime
                wn = (wn * w) % prime
        length <<= 1
    
    # 逆变换需要除以 n
    if inverse:
        n_inv = pow(n, prime - 2, prime)
        result = [(x * n_inv) % prime for x in result]
    
    return result

# 示例：使用 NTT 进行多项式乘法
def polynomial_multiply_ntt(poly1, poly2, prime):
    """使用 NTT 进行多项式乘法"""
    n = 1
    while n < len(poly1) + len(poly2) - 1:
        n <<= 1
    
    # 填充到 2 的幂长度
    a = poly1 + [0] * (n - len(poly1))
    b = poly2 + [0] * (n - len(poly2))
    
    # 正向 NTT
    a_ntt = ntt(a, prime)
    b_ntt = ntt(b, prime)
    
    # 点乘
    c_ntt = [(a_ntt[i] * b_ntt[i]) % prime for i in range(n)]
    
    # 逆向 NTT
    c = ntt(c_ntt, prime, inverse=True)
    
    # 移除前导零
    while len(c) > 1 and c[-1] == 0:
        c.pop()
    
    return c

# 测试
prime = 998244353  # NTT 友好素数
poly1 = [1, 2, 3]  # 3x² + 2x + 1
poly2 = [4, 5]     # 5x + 4

result = polynomial_multiply_ntt(poly1, poly2, prime)
print(f"多项式乘法结果: {result}")
```

## 4. ZKP中的应用

### 4.1 约束系统

在ZKP中，电路约束通常表示为多项式：

```python
class ConstraintSystem:
    """约束系统"""
    
    def __init__(self, field_prime):
        self.prime = field_prime
        self.constraints = []  # 约束多项式列表
        self.variables = {}    # 变量映射
    
    def add_constraint(self, left_poly, right_poly):
        """添加约束：left_poly = right_poly"""
        # 约束多项式：left_poly - right_poly = 0
        constraint = left_poly + Polynomial([-c for c in right_poly.coefficients], self.prime)
        self.constraints.append(constraint)
    
    def vanishing_polynomial(self, domain):
        """消失多项式：在域上所有点都为零"""
        # Z(x) = ∏(x - ωⁱ) for ωⁱ in domain
        result = Polynomial([1], self.prime)
        for point in domain:
            linear_factor = Polynomial([-point, 1], self.prime)  # (x - point)
            result = result * linear_factor
        return result
    
    def check_constraints(self, witness, domain):
        """检查约束是否满足"""
        for constraint in self.constraints:
            for point in domain:
                if constraint.evaluate(point) != 0:
                    return False
        return True

# 示例：简单的约束系统
cs = ConstraintSystem(17)

# 约束：x² - y = 0（即 y = x²）
x_squared = Polynomial([0, 0, 1], 17)  # x²
y = Polynomial([0, 1], 17)             # y

cs.add_constraint(x_squared, y)

# 验证见证
domain = [1, 2, 3, 4]
witness = {1: 1, 2: 4, 3: 9, 4: 16}  # x=1,2,3,4 对应 y=1,4,9,16

print(f"约束满足: {cs.check_constraints(witness, domain)}")
```

### 4.2 多项式承诺

多项式承诺允许承诺一个多项式而不泄露其内容：

```python
class PolynomialCommitment:
    """简化的多项式承诺方案"""
    
    def __init__(self, max_degree, field_prime):
        self.max_degree = max_degree
        self.prime = field_prime
        # 在实际实现中，这需要可信设置
        self.setup_params = self._trusted_setup()
    
    def _trusted_setup(self):
        """可信设置（简化版）"""
        import random
        tau = random.randint(1, self.prime - 1)  # 秘密值
        
        # 生成 [τ⁰, τ¹, τ², ..., τⁿ]
        powers_of_tau = []
        tau_power = 1
        for i in range(self.max_degree + 1):
            powers_of_tau.append(tau_power)
            tau_power = (tau_power * tau) % self.prime
        
        return powers_of_tau
    
    def commit(self, polynomial):
        """承诺多项式"""
        if polynomial.degree() > self.max_degree:
            raise ValueError("多项式度数超过最大支持度数")
        
        commitment = 0
        for i, coeff in enumerate(polynomial.coefficients):
            commitment = (commitment + coeff * self.setup_params[i]) % self.prime
        
        return commitment
    
    def open(self, polynomial, point):
        """在指定点打开承诺"""
        evaluation = polynomial.evaluate(point)
        
        # 计算商多项式 q(x) = (p(x) - p(z)) / (x - z)
        # 这里简化处理
        quotient_coeffs = []
        temp_poly = polynomial
        
        # 减去 p(z)
        if temp_poly.coefficients:
            temp_poly.coefficients[0] = (temp_poly.coefficients[0] - evaluation) % self.prime
        
        # 除以 (x - point)
        # 简化实现，实际需要多项式长除法
        for i in range(len(temp_poly.coefficients) - 1):
            quotient_coeffs.append(temp_poly.coefficients[i + 1])
        
        quotient = Polynomial(quotient_coeffs, self.prime)
        proof = self.commit(quotient)
        
        return evaluation, proof
    
    def verify(self, commitment, point, evaluation, proof):
        """验证打开"""
        # 简化验证：检查 commitment - evaluation = proof * (setup[1] - point)
        # 实际实现需要椭圆曲线配对
        left = (commitment - evaluation) % self.prime
        right = (proof * (self.setup_params[1] - point)) % self.prime
        return left == right

# 示例
pc = PolynomialCommitment(10, 17)
poly = Polynomial([1, 2, 3], 17)  # 3x² + 2x + 1

commitment = pc.commit(poly)
evaluation, proof = pc.open(poly, 5)
is_valid = pc.verify(commitment, 5, evaluation, proof)

print(f"承诺: {commitment}")
print(f"在点 5 的值: {evaluation}")
print(f"验证结果: {is_valid}")
```

## 5. 练习与思考

### 理论练习

1. **证明**：证明拉格朗日插值的唯一性。

2. **计算**：手工计算通过点 (0,1), (1,4), (2,9) 的插值多项式。

3. **分析**：分析 FFT 的时间复杂度，并与朴素多项式乘法比较。

### 编程练习

1. **实现**：实现多项式的长除法算法。

2. **优化**：实现 Karatsuba 多项式乘法算法。

3. **应用**：实现一个简单的多项式求值协议。

## 参考资料

### 经典教材
- **《Introduction to Algorithms》** - Cormen et al. (多项式与FFT章节)
- **《Modern Computer Algebra》** - von zur Gathen & Gerhard
- **《Computational Complexity》** - Arora & Barak

### ZKP相关论文
- **《Succinct Non-Interactive Zero Knowledge for a von Neumann Architecture》** - Ben-Sasson et al.
- **《Scalable, transparent, and post-quantum secure computational integrity》** - Ben-Sasson et al.
- **《PLONK: Permutations over Lagrange-bases for Oecumenical Noninteractive arguments of Knowledge》** - Gabizon et al.