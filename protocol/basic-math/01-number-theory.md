# 数论基础 (Number Theory Fundamentals)

## 概述

数论是研究整数性质的数学分支，是现代密码学和零知识证明的数学基石。本章涵盖ZKP中必需的数论概念。

### 学习目标
- 掌握整除、最大公约数、模运算等基本概念
- 理解欧几里得算法和扩展欧几里得算法
- 掌握中国剩余定理及其应用
- 理解二次剩余和勒让德符号

### 前置知识
- 基础代数知识
- 整数运算

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
数论是所有密码学协议的基础，在ZKP中用于：
- 有限域构造和运算
- 椭圆曲线密码学
- 承诺方案的安全性分析
- 随机数生成和素性测试

### 学习目标
- 掌握模运算的基本性质和计算方法
- 理解素数测试和因数分解的重要性
- 学会欧几里得算法和扩展欧几里得算法
- 理解离散对数问题及其在密码学中的应用

### 前置知识
- 基础代数知识
- 整数运算

### 在ZKP中的重要性 ⭐⭐⭐⭐⭐
数论为ZKP提供了安全性基础，特别是：
- 有限域运算的理论基础
- 椭圆曲线密码学的数学支撑
- 承诺方案和数字签名的安全性证明

## 1. 整数与除法

### 1.1 基本概念

**整除关系**：对于整数 a 和 b，如果存在整数 k 使得 a = kb，则称 b 整除 a，记作 b|a。

**最大公约数 (GCD)**：两个整数 a 和 b 的最大公约数是能同时整除 a 和 b 的最大正整数。

**最小公倍数 (LCM)**：两个整数 a 和 b 的最小公倍数是能被 a 和 b 同时整除的最小正整数。

### 1.2 欧几里得算法

计算两个整数最大公约数的高效算法：

```python
def gcd(a, b):
    """计算 a 和 b 的最大公约数"""
    while b != 0:
        a, b = b, a % b
    return a

def extended_gcd(a, b):
    """扩展欧几里得算法，返回 (gcd, x, y) 使得 ax + by = gcd(a,b)"""
    if b == 0:
        return a, 1, 0
    else:
        gcd, x1, y1 = extended_gcd(b, a % b)
        x = y1
        y = x1 - (a // b) * y1
        return gcd, x, y
```

**时间复杂度**：O(log min(a, b))

**在ZKP中的应用**：
- 计算模逆元
- 密钥生成
- 安全参数选择

## 2. 模运算 (Modular Arithmetic)

### 2.1 基本定义

对于整数 a, n (n > 0)，a 模 n 的余数记作 a mod n，满足：
$$a = qn + r, \quad 0 \leq r < n$$

其中 r = a mod n。

### 2.2 模运算性质

1. **(a + b) mod n = ((a mod n) + (b mod n)) mod n**
2. **(a - b) mod n = ((a mod n) - (b mod n)) mod n**  
3. **(a × b) mod n = ((a mod n) × (b mod n)) mod n**
4. **a^k mod n** 可以通过快速幂算法高效计算

### 2.3 模逆元

对于整数 a 和模数 n，如果存在整数 x 使得 ax ≡ 1 (mod n)，则称 x 为 a 模 n 的逆元。

**存在条件**：gcd(a, n) = 1

**计算方法**：使用扩展欧几里得算法

```python
def mod_inverse(a, n):
    """计算 a 模 n 的逆元"""
    gcd, x, y = extended_gcd(a, n)
    if gcd != 1:
        raise ValueError("模逆元不存在")
    return (x % n + n) % n
```

### 2.4 快速幂算法

```python
def fast_power(base, exp, mod):
    """计算 base^exp mod mod"""
    result = 1
    base = base % mod
    while exp > 0:
        if exp % 2 == 1:
            result = (result * base) % mod
        exp = exp >> 1
        base = (base * base) % mod
    return result
```

**时间复杂度**：O(log exp)

## 3. 素数理论

### 3.1 素数定义与性质

**素数**：大于1的自然数，只有1和自身两个正因数。

**重要性质**：
- 算术基本定理：每个大于1的整数都可以唯一分解为素数的乘积
- 素数无穷性：存在无穷多个素数
- 素数分布：素数定理描述了素数的分布规律

### 3.2 素性测试

**试除法**：检查是否能被小于√n的素数整除
```python
def is_prime_trial(n):
    """试除法素性测试"""
    if n < 2:
        return False
    if n == 2:
        return True
    if n % 2 == 0:
        return False
    
    for i in range(3, int(n**0.5) + 1, 2):
        if n % i == 0:
            return False
    return True
```

**Miller-Rabin 测试**：概率性素性测试
```python
import random

def miller_rabin(n, k=5):
    """Miller-Rabin 素性测试"""
    if n < 2:
        return False
    if n == 2 or n == 3:
        return True
    if n % 2 == 0:
        return False
    
    # 将 n-1 写成 2^r * d 的形式
    r = 0
    d = n - 1
    while d % 2 == 0:
        r += 1
        d //= 2
    
    # 进行 k 轮测试
    for _ in range(k):
        a = random.randrange(2, n - 1)
        x = fast_power(a, d, n)
        
        if x == 1 or x == n - 1:
            continue
        
        for _ in range(r - 1):
            x = fast_power(x, 2, n)
            if x == n - 1:
                break
        else:
            return False
    
    return True
```

### 3.3 素数生成

```python
def generate_prime(bits):
    """生成指定位数的素数"""
    while True:
        candidate = random.getrandbits(bits)
        candidate |= (1 << bits - 1) | 1  # 确保最高位和最低位为1
        if miller_rabin(candidate):
            return candidate
```

## 4. 中国剩余定理 (Chinese Remainder Theorem)

### 4.1 定理陈述

设 n₁, n₂, ..., nₖ 是两两互质的正整数，则同余方程组：
$$\begin{cases}
x \equiv a_1 \pmod{n_1} \\
x \equiv a_2 \pmod{n_2} \\
\vdots \\
x \equiv a_k \pmod{n_k}
\end{cases}$$

在模 N = n₁n₂...nₖ 意义下有唯一解。

### 4.2 构造性证明与算法

```python
def chinese_remainder_theorem(remainders, moduli):
    """中国剩余定理求解"""
    total = 0
    prod = 1
    for m in moduli:
        prod *= m
    
    for r, m in zip(remainders, moduli):
        p = prod // m
        total += r * mod_inverse(p, m) * p
    
    return total % prod
```

### 4.3 在密码学中的应用

- **RSA 加速**：利用CRT加速RSA解密
- **秘密分享**：Shamir秘密分享方案
- **多方计算**：分布式计算中的数据重构

## 5. 二次剩余理论

### 5.1 基本概念

**二次剩余**：对于奇素数 p 和整数 a，如果存在整数 x 使得 x² ≡ a (mod p)，则称 a 是模 p 的二次剩余。

**勒让德符号**：
$$\left(\frac{a}{p}\right) = \begin{cases}
0 & \text{if } p | a \\
1 & \text{if } a \text{ 是模 } p \text{ 的二次剩余} \\
-1 & \text{if } a \text{ 不是模 } p \text{ 的二次剩余}
\end{cases}$$

### 5.2 计算方法

```python
def legendre_symbol(a, p):
    """计算勒让德符号 (a/p)"""
    return fast_power(a, (p - 1) // 2, p)

def tonelli_shanks(n, p):
    """Tonelli-Shanks 算法求解二次剩余"""
    # 检查 n 是否为二次剩余
    if legendre_symbol(n, p) != 1:
        return None
    
    # 特殊情况：p ≡ 3 (mod 4)
    if p % 4 == 3:
        return fast_power(n, (p + 1) // 4, p)
    
    # 一般情况的 Tonelli-Shanks 算法
    # (实现略，较为复杂)
    pass
```

### 5.3 应用

- **椭圆曲线**：点的压缩与解压缩
- **零知识证明**：二次剩余问题的ZK证明
- **同态加密**：基于二次剩余的加密方案

## 6. 离散对数问题

### 6.1 问题定义

给定素数 p、生成元 g 和元素 h，求解 x 使得：
$$g^x \equiv h \pmod{p}$$

这个 x 称为 h 相对于基 g 模 p 的离散对数。

### 6.2 困难性

离散对数问题被认为是计算困难的，目前最好的算法复杂度为亚指数级。这一困难性是许多密码系统安全性的基础。

### 6.3 相关算法

**Baby-step Giant-step**：
- 时间复杂度：O(√p)
- 空间复杂度：O(√p)

**Pollard's rho**：
- 期望时间复杂度：O(√p)
- 空间复杂度：O(1)

## 7. 在ZKP中的应用总结

### 7.1 核心作用

1. **安全性基础**：大多数ZKP协议的安全性基于数论困难问题
2. **算法构造**：模运算、素数生成等是协议实现的基础
3. **参数选择**：安全参数的选择需要数论知识指导

### 7.2 具体应用场景

| 数论概念 | ZKP应用 | 具体协议 |
|---------|---------|----------|
| 模运算 | 有限域计算 | 所有协议 |
| 素数 | 安全参数 | RSA, Paillier |
| 离散对数 | 承诺方案 | Pedersen, Bulletproofs |
| 二次剩余 | 椭圆曲线 | ECDSA, EdDSA |
| 中国剩余定理 | 秘密分享 | Shamir's scheme |

## 练习题

1. 实现扩展欧几里得算法并验证其正确性
2. 编写Miller-Rabin素性测试的完整实现
3. 使用中国剩余定理解决实际问题
4. 分析不同素性测试算法的性能差异
5. 研究离散对数问题在具体ZKP协议中的应用

