# 有限域理论 (Finite Field Theory)

## 概述

有限域（也称为伽罗瓦域）是包含有限个元素的域，在零知识证明中扮演核心角色。所有的电路运算、多项式计算都在有限域上进行。

### 学习目标
- 理解域的定义和基本性质
- 掌握有限域的构造方法
- 理解本原元素和生成元的概念
- 掌握有限域上的多项式运算

### 前置知识
- 数论基础（模运算、素数）
- 群论基础（群、环、域的概念）

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
有限域是ZKP的计算基础：
- 所有电路变量都是有限域元素
- 多项式承诺在有限域上定义
- 椭圆曲线定义在有限域上
- FFT和NTT需要特定的有限域

## 1. 域的基本概念

### 1.1 域的定义

**域 (Field)**：一个集合 F 配备两个运算（加法 + 和乘法 ·），满足：

1. **(F, +) 是阿贝尔群**：
   - 加法封闭性：∀a, b ∈ F, a + b ∈ F
   - 加法结合律：∀a, b, c ∈ F, (a + b) + c = a + (b + c)
   - 加法单位元：∃0 ∈ F, ∀a ∈ F, a + 0 = a
   - 加法逆元：∀a ∈ F, ∃(-a) ∈ F, a + (-a) = 0
   - 加法交换律：∀a, b ∈ F, a + b = b + a

2. **(F\{0}, ·) 是阿贝尔群**：
   - 乘法封闭性：∀a, b ∈ F\{0}, a · b ∈ F\{0}
   - 乘法结合律：∀a, b, c ∈ F, (a · b) · c = a · (b · c)
   - 乘法单位元：∃1 ∈ F, ∀a ∈ F, a · 1 = a
   - 乘法逆元：∀a ∈ F\{0}, ∃a⁻¹ ∈ F, a · a⁻¹ = 1
   - 乘法交换律：∀a, b ∈ F, a · b = b · a

3. **分配律**：∀a, b, c ∈ F, a · (b + c) = a · b + a · c

### 1.2 有限域的存在性

**定理**：有限域存在当且仅当其元素个数是素数的幂，即 |F| = p^n，其中 p 是素数，n 是正整数。

**记号**：阶为 p^n 的有限域记作 F_{p^n} 或 GF(p^n)。

## 2. 素域 F_p

### 2.1 构造

最简单的有限域是素域 F_p = Z/pZ = {0, 1, 2, ..., p-1}，其中 p 是素数。

运算定义：
- 加法：a +_p b = (a + b) mod p
- 乘法：a ·_p b = (a · b) mod p

```python
class FiniteFieldElement:
    """有限域 F_p 中的元素"""
    
    def __init__(self, value, prime):
        self.value = value % prime
        self.prime = prime
    
    def __add__(self, other):
        if self.prime != other.prime:
            raise ValueError("不同素数的有限域元素不能相加")
        return FiniteFieldElement((self.value + other.value) % self.prime, self.prime)
    
    def __mul__(self, other):
        if self.prime != other.prime:
            raise ValueError("不同素数的有限域元素不能相乘")
        return FiniteFieldElement((self.value * other.value) % self.prime, self.prime)
    
    def __pow__(self, exponent):
        """快速幂运算"""
        return FiniteFieldElement(pow(self.value, exponent, self.prime), self.prime)
    
    def inverse(self):
        """计算乘法逆元"""
        if self.value == 0:
            raise ValueError("0 没有乘法逆元")
        return FiniteFieldElement(pow(self.value, self.prime - 2, self.prime), self.prime)

# 示例：F_7 中的运算
p = 7
a = FiniteFieldElement(3, p)
b = FiniteFieldElement(5, p)

print(f"3 + 5 = {(a + b).value} (mod 7)")  # 输出: 1
print(f"3 * 5 = {(a * b).value} (mod 7)")  # 输出: 1
print(f"3^(-1) = {a.inverse().value} (mod 7)")  # 输出: 5
```

### 2.2 费马小定理

**费马小定理**：如果 p 是素数，a 不被 p 整除，则 a^{p-1} ≡ 1 (mod p)。

**推论**：在 F_p 中，对于非零元素 a，有 a^{-1} = a^{p-2}。

## 3. ZKP中的应用

### 3.1 电路运算

在ZKP中，所有的电路变量都是有限域元素：

```python
# 典型的ZKP友好素数
BN254_SCALAR_FIELD = 21888242871839275222246405745257275088548364400416034343698204186575808495617
BLS12_381_SCALAR_FIELD = 52435875175126190479447740508185965837690552500527637822603658699938581184513

class CircuitVariable:
    """电路变量（有限域元素）"""
    
    def __init__(self, value, field_prime=BN254_SCALAR_FIELD):
        self.value = value % field_prime
        self.prime = field_prime
    
    def __add__(self, other):
        return CircuitVariable((self.value + other.value) % self.prime, self.prime)
    
    def __mul__(self, other):
        return CircuitVariable((self.value * other.value) % self.prime, self.prime)
    
    def __sub__(self, other):
        return CircuitVariable((self.value - other.value) % self.prime, self.prime)

# 示例：简单的电路约束 a * b = c
a = CircuitVariable(3)
b = CircuitVariable(5)
c = CircuitVariable(15)

# 验证约束
constraint_satisfied = (a * b).value == c.value
print(f"约束 a * b = c 满足: {constraint_satisfied}")
```

## 参考资料

### 经典教材
- **《Introduction to Modern Cryptography》** - Katz & Lindell
- **《A Course in Number Theory and Cryptography》** - Neal Koblitz
- **《Finite Fields and Their Applications》** - Gary L. Mullen

### ZKP相关论文
- **《Quadratic Arithmetic Programs》** - Gennaro et al.
- **《PLONK》** - Gabizon, Williamson, Ciobotaru