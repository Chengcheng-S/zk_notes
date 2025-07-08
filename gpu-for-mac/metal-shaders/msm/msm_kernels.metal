#include <metal_stdlib>
using namespace metal;

// BLS12-381 椭圆曲线参数
// 基域模数 p = 4002409555221667393417789825735904156556882819939007885332058136124031650490837864442687629129015664037894272559787
constant uint64_t BLS12_381_BASE_MODULUS[6] = {
    0xb9feffffffffaaab,
    0x1eabfffeb153ffff,
    0x6730d2a0f6b0f624,
    0x64774b84f38512bf,
    0x4b1ba7b6434bacd7,
    0x1a0111ea397fe69a
};

// 标量域模数 r
constant uint64_t BLS12_381_SCALAR_MODULUS[4] = {
    0x73eda753299d7d48,
    0x06d89f71cab8351f,
    0x2833e84879b97091,
    0x30644e72e131a029
};

// 基域元素（384位，6个64位limb）
struct Fp {
    uint64_t limbs[6];
};

// 标量域元素（256位，4个64位limb）
struct Fr {
    uint64_t limbs[4];
};

// G1 点（雅可比坐标）
struct G1Point {
    Fp x;
    Fp y;
    Fp z;
    bool is_infinity;
};

// 预计算的窗口表
struct WindowTable {
    G1Point points[16];  // 2^4 = 16 个预计算点
};

// 基域运算函数

// Fp 加法
Fp fp_add(Fp a, Fp b) {
    Fp result;
    uint64_t carry = 0;
    
    for (int i = 0; i < 6; i++) {
        uint64_t sum = a.limbs[i] + b.limbs[i] + carry;
        result.limbs[i] = sum;
        carry = (sum < a.limbs[i]) ? 1 : 0;
    }
    
    // 条件减法
    bool should_reduce = carry > 0;
    if (!should_reduce) {
        for (int i = 5; i >= 0; i--) {
            if (result.limbs[i] > BLS12_381_BASE_MODULUS[i]) {
                should_reduce = true;
                break;
            } else if (result.limbs[i] < BLS12_381_BASE_MODULUS[i]) {
                break;
            }
        }
    }
    
    if (should_reduce) {
        uint64_t borrow = 0;
        for (int i = 0; i < 6; i++) {
            uint64_t temp = result.limbs[i] - BLS12_381_BASE_MODULUS[i] - borrow;
            result.limbs[i] = temp;
            borrow = (temp > result.limbs[i]) ? 1 : 0;
        }
    }
    
    return result;
}

// Fp 减法
Fp fp_sub(Fp a, Fp b) {
    Fp result;
    bool need_borrow = false;
    
    // 检查是否需要借位
    for (int i = 5; i >= 0; i--) {
        if (a.limbs[i] < b.limbs[i]) {
            need_borrow = true;
            break;
        } else if (a.limbs[i] > b.limbs[i]) {
            break;
        }
    }
    
    if (need_borrow) {
        // a < b，计算 a + p - b
        Fp temp = fp_add(a, Fp{{
            BLS12_381_BASE_MODULUS[0],
            BLS12_381_BASE_MODULUS[1],
            BLS12_381_BASE_MODULUS[2],
            BLS12_381_BASE_MODULUS[3],
            BLS12_381_BASE_MODULUS[4],
            BLS12_381_BASE_MODULUS[5]
        }});
        
        uint64_t borrow = 0;
        for (int i = 0; i < 6; i++) {
            uint64_t diff = temp.limbs[i] - b.limbs[i] - borrow;
            result.limbs[i] = diff;
            borrow = (diff > temp.limbs[i]) ? 1 : 0;
        }
    } else {
        uint64_t borrow = 0;
        for (int i = 0; i < 6; i++) {
            uint64_t diff = a.limbs[i] - b.limbs[i] - borrow;
            result.limbs[i] = diff;
            borrow = (diff > a.limbs[i]) ? 1 : 0;
        }
    }
    
    return result;
}

// Fp 乘法（简化版本）
Fp fp_mul(Fp a, Fp b) {
    // 这里应该实现完整的蒙哥马利乘法
    // 为了演示，使用简化版本
    Fp result = {{0, 0, 0, 0, 0, 0}};
    
    // 只计算最低位的乘积（简化）
    uint64_t low_prod = a.limbs[0] * b.limbs[0];
    result.limbs[0] = low_prod % BLS12_381_BASE_MODULUS[0];
    
    return result;
}

// Fp 平方
Fp fp_square(Fp a) {
    return fp_mul(a, a);
}

// 椭圆曲线点运算

// 检查点是否为无穷远点
bool is_infinity(G1Point p) {
    return p.is_infinity;
}

// 点加法（雅可比坐标）
G1Point point_add(G1Point p1, G1Point p2) {
    if (is_infinity(p1)) return p2;
    if (is_infinity(p2)) return p1;
    
    // 雅可比坐标点加法
    // (X1, Y1, Z1) + (X2, Y2, Z2)
    
    Fp z1z1 = fp_square(p1.z);  // Z1²
    Fp z2z2 = fp_square(p2.z);  // Z2²
    
    Fp u1 = fp_mul(p1.x, z2z2);  // U1 = X1 * Z2²
    Fp u2 = fp_mul(p2.x, z1z1);  // U2 = X2 * Z1²
    
    Fp s1 = fp_mul(p1.y, fp_mul(p2.z, z2z2));  // S1 = Y1 * Z2³
    Fp s2 = fp_mul(p2.y, fp_mul(p1.z, z1z1));  // S2 = Y2 * Z1³
    
    Fp h = fp_sub(u2, u1);  // H = U2 - U1
    Fp r = fp_sub(s2, s1);  // R = S2 - S1
    
    // 检查是否为相同点或相反点
    bool same_x = true;
    bool same_y = true;
    
    for (int i = 0; i < 6; i++) {
        if (h.limbs[i] != 0) same_x = false;
        if (r.limbs[i] != 0) same_y = false;
    }
    
    if (same_x) {
        if (same_y) {
            // 相同点，执行点倍乘
            return point_double(p1);
        } else {
            // 相反点，返回无穷远点
            return G1Point{{{{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, true}};
        }
    }
    
    Fp hh = fp_square(h);      // H²
    Fp hhh = fp_mul(h, hh);    // H³
    Fp u1hh = fp_mul(u1, hh);  // U1 * H²
    
    // X3 = R² - H³ - 2 * U1 * H²
    Fp x3 = fp_sub(fp_sub(fp_square(r), hhh), fp_add(u1hh, u1hh));
    
    // Y3 = R * (U1 * H² - X3) - S1 * H³
    Fp y3 = fp_sub(fp_mul(r, fp_sub(u1hh, x3)), fp_mul(s1, hhh));
    
    // Z3 = Z1 * Z2 * H
    Fp z3 = fp_mul(fp_mul(p1.z, p2.z), h);
    
    return G1Point{{x3, y3, z3, false}};
}

// 点倍乘（雅可比坐标）
G1Point point_double(G1Point p) {
    if (is_infinity(p)) return p;
    
    Fp a = fp_square(p.y);     // A = Y²
    Fp b = fp_add(a, a);       // B = 2A
    Fp b2 = fp_add(b, b);      // 4A
    Fp c = fp_add(b2, b2);     // C = 8A
    
    Fp d = fp_mul(p.x, b);     // D = X * B
    Fp e = fp_square(p.x);     // E = X²
    Fp e3 = fp_add(fp_add(e, e), e);  // 3E
    
    // X' = 9E² - 2D
    Fp x3 = fp_sub(fp_square(e3), fp_add(d, d));
    
    // Y' = 3E(D - X') - C
    Fp y3 = fp_sub(fp_mul(e3, fp_sub(d, x3)), c);
    
    // Z' = 2YZ
    Fp z3 = fp_mul(fp_add(p.y, p.y), p.z);
    
    return G1Point{{x3, y3, z3, false}};
}

// 标量乘法（二进制方法）
G1Point scalar_mul(G1Point base, Fr scalar) {
    G1Point result = {{{{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, true}};
    G1Point addend = base;
    
    for (int i = 0; i < 4; i++) {
        uint64_t limb = scalar.limbs[i];
        
        for (int bit = 0; bit < 64; bit++) {
            if (limb & 1) {
                result = point_add(result, addend);
            }
            addend = point_double(addend);
            limb >>= 1;
        }
    }
    
    return result;
}

// MSM 内核

// 朴素 MSM 内核
kernel void naive_msm_kernel(
    device const Fr* scalars [[buffer(0)]],
    device const G1Point* points [[buffer(1)]],
    device G1Point* partial_results [[buffer(2)]],
    constant uint& start_idx [[buffer(3)]],
    constant uint& count [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= count) return;
    
    uint idx = start_idx + gid;
    partial_results[gid] = scalar_mul(points[idx], scalars[idx]);
}

// 分桶 MSM 内核
kernel void bucket_msm_kernel(
    device const Fr* scalars [[buffer(0)]],
    device const G1Point* points [[buffer(1)]],
    device G1Point* buckets [[buffer(2)]],
    constant uint& window_start [[buffer(3)]],
    constant uint& window_size [[buffer(4)]],
    constant uint& num_points [[buffer(5)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= num_points) return;
    
    Fr scalar = scalars[gid];
    G1Point point = points[gid];
    
    // 提取窗口位
    uint window_bits = 0;
    uint limb_idx = window_start / 64;
    uint bit_offset = window_start % 64;
    
    if (limb_idx < 4) {
        uint64_t limb = scalar.limbs[limb_idx];
        window_bits = (limb >> bit_offset) & ((1 << window_size) - 1);
        
        // 处理跨越两个 limb 的情况
        if (bit_offset + window_size > 64 && limb_idx + 1 < 4) {
            uint remaining_bits = (bit_offset + window_size) - 64;
            uint64_t next_limb = scalar.limbs[limb_idx + 1];
            window_bits |= (next_limb & ((1 << remaining_bits) - 1)) << (64 - bit_offset);
        }
    }
    
    // 跳过零桶
    if (window_bits == 0) return;
    
    // 原子加法到对应的桶
    // 注意：Metal 不直接支持结构体的原子操作，需要使用锁或其他同步机制
    // 这里简化处理，实际实现需要更复杂的同步
    buckets[window_bits] = point_add(buckets[window_bits], point);
}

// 桶聚合内核
kernel void bucket_aggregate_kernel(
    device G1Point* buckets [[buffer(0)]],
    device G1Point* result [[buffer(1)]],
    constant uint& num_buckets [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid != 0) return;  // 只有一个线程执行
    
    G1Point sum = {{{{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, true}};
    G1Point running_sum = {{{{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, true}};
    
    // 从最高桶开始累加
    for (int i = num_buckets - 1; i > 0; i--) {
        running_sum = point_add(running_sum, buckets[i]);
        sum = point_add(sum, running_sum);
    }
    
    result[0] = sum;
}

// 预计算窗口表内核
kernel void precompute_window_kernel(
    device const G1Point* base_points [[buffer(0)]],
    device WindowTable* window_tables [[buffer(1)]],
    constant uint& num_points [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= num_points) return;
    
    G1Point base = base_points[gid];
    WindowTable table;
    
    // 预计算 [0, 1, 2, ..., 15] * base
    table.points[0] = {{{{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, {{0,0,0,0,0,0}}, true}};  // 0 * base = O
    table.points[1] = base;  // 1 * base
    
    for (int i = 2; i < 16; i++) {
        table.points[i] = point_add(table.points[i-1], base);
    }
    
    window_tables[gid] = table;
}

// 窗口方法 MSM 内核
kernel void windowed_msm_kernel(
    device const Fr* scalars [[buffer(0)]],
    device const WindowTable* window_tables [[buffer(1)]],
    device G1Point* partial_results [[buffer(2)]],
    constant uint& window_start [[buffer(3)]],
    constant uint& window_size [[buffer(4)]],
    constant uint& num_points [[buffer(5)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= num_points) return;
    
    Fr scalar = scalars[gid];
    WindowTable table = window_tables[gid];
    
    // 提取窗口位
    uint window_bits = 0;
    uint limb_idx = window_start / 64;
    uint bit_offset = window_start % 64;
    
    if (limb_idx < 4) {
        uint64_t limb = scalar.limbs[limb_idx];
        window_bits = (limb >> bit_offset) & ((1 << window_size) - 1);
        
        if (bit_offset + window_size > 64 && limb_idx + 1 < 4) {
            uint remaining_bits = (bit_offset + window_size) - 64;
            uint64_t next_limb = scalar.limbs[limb_idx + 1];
            window_bits |= (next_limb & ((1 << remaining_bits) - 1)) << (64 - bit_offset);
        }
    }
    
    // 从预计算表中获取结果
    partial_results[gid] = table.points[window_bits];
}

// 并行点加法约简内核
kernel void parallel_reduction_kernel(
    device G1Point* points [[buffer(0)]],
    constant uint& n [[buffer(1)]],
    constant uint& stride [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    uint idx = gid * stride * 2;
    
    if (idx + stride < n) {
        points[idx] = point_add(points[idx], points[idx + stride]);
    }
}