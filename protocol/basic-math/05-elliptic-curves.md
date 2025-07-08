# 椭圆曲线密码学 (Elliptic Curve Cryptography)

## 概述

椭圆曲线是现代密码学的核心工具，在零知识证明中用于构造数字签名、承诺方案和配对运算。本章涵盖椭圆曲线的数学理论和密码学应用。

### 学习目标
- 理解椭圆曲线的数学定义
- 掌握椭圆曲线上的点运算
- 理解椭圆曲线离散对数问题
- 掌握常用椭圆曲线参数

### 前置知识
- 有限域理论
- 群论基础
- 数论基础

### 在ZKP中的重要性 ⭐⭐⭐⭐
椭圆曲线在ZKP中的应用：
- 数字签名验证
- Pedersen承诺方案
- 双线性配对运算
- 多项式承诺方案

## 1. 椭圆曲线的定义

### 1.1 Weierstrass形式

**椭圆曲线**：在有限域 F_p (p > 3) 上，椭圆曲线由方程定义：
$$E: y^2 = x^3 + ax + b$$
其中 a, b ∈ F_p，且判别式 Δ = -16(4a³ + 27b²) ≠ 0。

**椭圆曲线上的点**：
- 满足曲线方程的点 (x, y)
- 无穷远点 O（群的单位元）

### 1.2 点的加法运算

椭圆曲线上的点构成阿贝尔群 (E(F_p), +)：

**点加法规则**：
1. **单位元**：O + P = P + O = P
2. **逆元**：P = (x, y) 的逆元是 -P = (x, -y)
3. **一般加法**：设 P₁ = (x₁, y₁), P₂ = (x₂, y₂)

   - 如果 x₁ ≠ x₂：
     $$λ = \frac{y₂ - y₁}{x₂ - x₁}$$
     $$x₃ = λ² - x₁ - x₂$$
     $$y₃ = λ(x₁ - x₃) - y₁$$

   - 如果 P₁ = P₂（点倍乘）：
     $$λ = \frac{3x₁² + a}{2y₁}$$
     $$x₃ = λ² - 2x₁$$
     $$y₃ = λ(x₁ - x₃) - y₁$$

```python
class EllipticCurvePoint:
    """椭圆曲线上的点"""
    
    def __init__(self, x, y, curve):
        self.x = x
        self.y = y
        self.curve = curve
        self.is_infinity = False
        
        if x is not None and y is not None:
            # 验证点在曲线上
            if not self._is_on_curve():
                raise ValueError("点不在椭圆曲线上")
    
    @classmethod
    def infinity(cls, curve):
        """无穷远点"""
        point = cls(None, None, curve)
        point.is_infinity = True
        return point
    
    def _is_on_curve(self):
        """检查点是否在曲线上"""
        if self.is_infinity:
            return True
        
        left = (self.y * self.y) % self.curve.p
        right = (self.x * self.x * self.x + self.curve.a * self.x + self.curve.b) % self.curve.p
        return left == right
    
    def __add__(self, other):
        """点加法"""
        if self.is_infinity:
            return other
        if other.is_infinity:
            return self
        
        # 检查是否为逆元
        if self.x == other.x:
            if self.y == other.y:
                return self._double()
            else:
                return EllipticCurvePoint.infinity(self.curve)
        
        # 一般加法
        lambda_val = ((other.y - self.y) * pow(other.x - self.x, self.curve.p - 2, self.curve.p)) % self.curve.p
        x3 = (lambda_val * lambda_val - self.x - other.x) % self.curve.p
        y3 = (lambda_val * (self.x - x3) - self.y) % self.curve.p
        
        return EllipticCurvePoint(x3, y3, self.curve)
    
    def _double(self):
        """点倍乘"""
        if self.is_infinity or self.y == 0:
            return EllipticCurvePoint.infinity(self.curve)
        
        lambda_val = ((3 * self.x * self.x + self.curve.a) * pow(2 * self.y, self.curve.p - 2, self.curve.p)) % self.curve.p
        x3 = (lambda_val * lambda_val - 2 * self.x) % self.curve.p
        y3 = (lambda_val * (self.x - x3) - self.y) % self.curve.p
        
        return EllipticCurvePoint(x3, y3, self.curve)
    
    def __mul__(self, scalar):
        """标量乘法（二进制方法）"""
        if scalar == 0:
            return EllipticCurvePoint.infinity(self.curve)
        if scalar == 1:
            return self
        
        result = EllipticCurvePoint.infinity(self.curve)
        addend = self
        
        while scalar > 0:
            if scalar & 1:
                result = result + addend
            addend = addend._double()
            scalar >>= 1
        
        return result

class EllipticCurve:
    """椭圆曲线"""
    
    def __init__(self, a, b, p):
        self.a = a % p
        self.b = b % p
        self.p = p
        
        # 检查判别式
        discriminant = (-16 * (4 * a**3 + 27 * b**2)) % p
        if discriminant == 0:
            raise ValueError("无效的椭圆曲线参数")
    
    def point(self, x, y):
        """创建曲线上的点"""
        return EllipticCurvePoint(x, y, self)
    
    def infinity(self):
        """无穷远点"""
        return EllipticCurvePoint.infinity(self)

# 示例：secp256k1 曲线（简化版）
p = 2**256 - 2**32 - 977  # secp256k1的素数
curve = EllipticCurve(0, 7, p)  # y² = x³ + 7

# 生成元G（实际值需要查表）
G = curve.point(
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8
)

# 标量乘法示例
k = 12345
kG = G * k
print(f"k*G = ({hex(kG.x)}, {hex(kG.y)})")
```

## 2. 常用椭圆曲线

### 2.1 secp256k1

Bitcoin和以太坊使用的曲线：
- **方程**：y² = x³ + 7
- **素数**：p = 2²⁵⁶ - 2³² - 977
- **阶**：n = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141

### 2.2 BN254 (alt_bn128)

ZKP中常用的配对友好曲线：
- **素数**：p = 21888242871839275222246405745257275088696311157297823662689037894645226208583
- **标量域**：r = 21888242871839275222246405745257275088548364400416034343698204186575808495617

### 2.3 BLS12-381

现代ZKP系统的首选曲线：
- **素数**：p = 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787
- **嵌入度**：k = 12
- **安全级别**：128位

```python
# BN254曲线参数
class BN254:
    # 基域素数
    P = 21888242871839275222246405745257275088696311157297823662689037894645226208583
    # 标量域素数  
    R = 21888242871839275222246405745257275088548364400416034343698204186575808495617
    
    # 曲线参数 y² = x³ + 3
    A = 0
    B = 3
    
    # 生成元
    GX = 1
    GY = 2

# BLS12-381曲线参数
class BLS12_381:
    # 基域素数
    P = 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787
    # 标量域素数
    R = 52435875175126190479447740508185965837690552500527637822603658699938581184513
    
    # 曲线参数 y² = x³ + 4
    A = 0
    B = 4
```

## 3. 椭圆曲线离散对数问题

### 3.1 问题定义

**椭圆曲线离散对数问题 (ECDLP)**：
给定椭圆曲线上的点 P 和 Q，找到整数 k 使得 Q = kP。

**困难性假设**：对于密码学安全的椭圆曲线，ECDLP 在多项式时间内不可解。

### 3.2 安全性分析

```python
def pollard_rho_ecdlp(P, Q, n):
    """Pollard's rho算法求解ECDLP（演示用）"""
    import random
    
    def f(x, a, b):
        """迭代函数"""
        if x.x % 3 == 0:
            return x + x, (2 * a) % n, (2 * b) % n
        elif x.x % 3 == 1:
            return x + P, (a + 1) % n, b
        else:
            return x + Q, a, (b + 1) % n
    
    # 初始化
    x1 = P.curve.infinity()
    a1, b1 = 0, 0
    x2, a2, b2 = x1, a1, b1
    
    # Floyd判圈算法
    for i in range(int(n**0.5) + 1):
        x1, a1, b1 = f(x1, a1, b1)
        x2, a2, b2 = f(*f(x2, a2, b2))
        
        if x1.x == x2.x and x1.y == x2.y:
            # 找到碰撞
            r = (b1 - b2) % n
            if r != 0:
                r_inv = pow(r, n - 2, n)
                k = ((a2 - a1) * r_inv) % n
                return k
    
    return None

# 注意：这个算法仅用于演示，实际的ECDLP求解需要指数时间
```

## 4. ZKP中的应用

### 4.1 Pedersen承诺

```python
class PedersenCommitment:
    """基于椭圆曲线的Pedersen承诺"""
    
    def __init__(self, curve, G, H):
        self.curve = curve
        self.G = G  # 生成元1
        self.H = H  # 生成元2（需要满足H = kG的k未知）
    
    def commit(self, value, randomness):
        """承诺：C = vG + rH"""
        return self.G * value + self.H * randomness
    
    def verify(self, commitment, value, randomness):
        """验证承诺"""
        expected = self.G * value + self.H * randomness
        return commitment.x == expected.x and commitment.y == expected.y

# 示例
curve = EllipticCurve(0, 7, 23)  # 小素数示例
G = curve.point(1, 7)
H = curve.point(4, 5)  # 假设这是另一个生成元

pc = PedersenCommitment(curve, G, H)

# 承诺值5，随机数3
value = 5
randomness = 3
commitment = pc.commit(value, randomness)

# 验证
is_valid = pc.verify(commitment, value, randomness)
print(f"承诺验证: {is_valid}")
```

### 4.2 ECDSA签名

```python
class ECDSA:
    """椭圆曲线数字签名算法"""
    
    def __init__(self, curve, G, n):
        self.curve = curve
        self.G = G      # 基点
        self.n = n      # 基点的阶
    
    def generate_keypair(self):
        """生成密钥对"""
        import random
        private_key = random.randint(1, self.n - 1)
        public_key = self.G * private_key
        return private_key, public_key
    
    def sign(self, message_hash, private_key):
        """签名"""
        import random
        
        while True:
            k = random.randint(1, self.n - 1)
            R = self.G * k
            r = R.x % self.n
            
            if r == 0:
                continue
            
            k_inv = pow(k, self.n - 2, self.n)
            s = (k_inv * (message_hash + r * private_key)) % self.n
            
            if s != 0:
                return (r, s)
    
    def verify(self, message_hash, signature, public_key):
        """验证签名"""
        r, s = signature
        
        if not (1 <= r < self.n and 1 <= s < self.n):
            return False
        
        s_inv = pow(s, self.n - 2, self.n)
        u1 = (message_hash * s_inv) % self.n
        u2 = (r * s_inv) % self.n
        
        point = self.G * u1 + public_key * u2
        
        if point.is_infinity:
            return False
        
        return (point.x % self.n) == r

# 示例（使用小参数）
curve = EllipticCurve(0, 7, 23)
G = curve.point(1, 7)
n = 19  # 假设的基点阶

ecdsa = ECDSA(curve, G, n)
private_key, public_key = ecdsa.generate_keypair()

message_hash = 12  # 实际应用中是哈希值
signature = ecdsa.sign(message_hash, private_key)
is_valid = ecdsa.verify(message_hash, signature, public_key)

print(f"ECDSA验证: {is_valid}")
```

## 参考资料

### 经典教材
- **《Guide to Elliptic Curve Cryptography》** - Hankerson, Menezes, Vanstone
- **《Elliptic Curves: Number Theory and Cryptography》** - Washington
- **《Introduction to Mathematical Cryptography》** - Hoffstein, Pipher, Silverman

### 标准文档
- **RFC 5639** - Elliptic Curve Cryptography (ECC) Brainpool Standard Curves
- **SEC 2** - Recommended Elliptic Curve Domain Parameters
- **NIST FIPS 186-4** - Digital Signature Standard