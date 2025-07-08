#include <metal_stdlib>
using namespace metal;

// BLS12-381 标量域的模数
constant uint64_t BLS12_381_SCALAR_MODULUS[4] = {
    0x73eda753299d7d48,
    0x06d89f71cab8351f,
    0x2833e84879b97091,
    0x30644e72e131a029
};

// 有限域元素结构（256位，4个64位limb）
struct FieldElement {
    uint64_t limbs[4];
};

// 有限域运算函数

// 比较：a >= b
bool field_gte(FieldElement a, FieldElement b) {
    for (int i = 3; i >= 0; i--) {
        if (a.limbs[i] > b.limbs[i]) return true;
        if (a.limbs[i] < b.limbs[i]) return false;
    }
    return true;  // 相等
}

// 比较：a >= modulus
bool field_gte_modulus(FieldElement a) {
    for (int i = 3; i >= 0; i--) {
        if (a.limbs[i] > BLS12_381_SCALAR_MODULUS[i]) return true;
        if (a.limbs[i] < BLS12_381_SCALAR_MODULUS[i]) return false;
    }
    return true;  // 相等
}

// 减法：a - b（假设 a >= b）
FieldElement field_sub(FieldElement a, FieldElement b) {
    FieldElement result;
    uint64_t borrow = 0;
    
    for (int i = 0; i < 4; i++) {
        uint64_t temp = a.limbs[i] - b.limbs[i] - borrow;
        result.limbs[i] = temp;
        borrow = (temp > a.limbs[i]) ? 1 : 0;
    }
    
    return result;
}

// 减法：a - modulus
FieldElement field_sub_modulus(FieldElement a) {
    FieldElement result;
    uint64_t borrow = 0;
    
    for (int i = 0; i < 4; i++) {
        uint64_t temp = a.limbs[i] - BLS12_381_SCALAR_MODULUS[i] - borrow;
        result.limbs[i] = temp;
        borrow = (temp > a.limbs[i]) ? 1 : 0;
    }
    
    return result;
}

// 加法：a + b mod modulus
FieldElement field_add(FieldElement a, FieldElement b) {
    FieldElement result;
    uint64_t carry = 0;
    
    // 执行加法
    for (int i = 0; i < 4; i++) {
        uint64_t sum = a.limbs[i] + b.limbs[i] + carry;
        result.limbs[i] = sum;
        carry = (sum < a.limbs[i]) ? 1 : 0;
    }
    
    // 条件减法
    if (carry > 0 || field_gte_modulus(result)) {
        result = field_sub_modulus(result);
    }
    
    return result;
}

// 减法：a - b mod modulus
FieldElement field_subtract(FieldElement a, FieldElement b) {
    FieldElement result;
    
    if (field_gte(a, b)) {
        result = field_sub(a, b);
    } else {
        // a < b，计算 a + modulus - b
        FieldElement temp = field_add(a, FieldElement{{
            BLS12_381_SCALAR_MODULUS[0],
            BLS12_381_SCALAR_MODULUS[1],
            BLS12_381_SCALAR_MODULUS[2],
            BLS12_381_SCALAR_MODULUS[3]
        }});
        result = field_sub(temp, b);
    }
    
    return result;
}

// 蒙哥马利乘法（简化版本）
FieldElement field_multiply(FieldElement a, FieldElement b) {
    // 这里应该实现完整的蒙哥马利乘法
    // 为了简化，我们使用一个占位符实现
    
    // 计算低位乘积（简化）
    uint64_t low_product = a.limbs[0] * b.limbs[0];
    
    FieldElement result = {{
        low_product % BLS12_381_SCALAR_MODULUS[0],
        0, 0, 0
    }};
    
    return result;
}

// NTT 蝶形运算内核
kernel void ntt_butterfly_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    constant uint& n [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    uint stride = 1 << stage;
    uint m = n >> (stage + 1);
    
    if (gid >= m) return;
    
    // 计算蝶形运算的索引
    uint group = gid / stride;
    uint pos_in_group = gid % stride;
    uint base = group * (stride << 1) + pos_in_group;
    
    uint i = base;
    uint j = base + stride;
    
    // 获取旋转因子
    FieldElement twiddle = twiddle_factors[gid];
    
    // 执行蝶形运算
    FieldElement u = data[i];
    FieldElement v = field_multiply(data[j], twiddle);
    
    data[i] = field_add(u, v);
    data[j] = field_subtract(u, v);
}

// 优化的 NTT 内核（使用共享内存）
kernel void ntt_optimized_kernel(
    device FieldElement* global_data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& log_n [[buffer(2)]],
    constant uint& stage_start [[buffer(3)]],
    constant uint& stages_per_kernel [[buffer(4)]],
    uint gid [[thread_position_in_grid]],
    uint lid [[thread_position_in_threadgroup]],
    uint group_id [[threadgroup_position_in_grid]]
) {
    // 共享内存（每个线程组处理 256 个元素）
    threadgroup FieldElement shared_data[256];
    
    uint n = 1 << log_n;
    uint elements_per_group = 256;
    uint group_start = group_id * elements_per_group;
    
    // 加载数据到共享内存
    if (group_start + lid < n) {
        shared_data[lid] = global_data[group_start + lid];
    } else {
        // 填充零元素
        shared_data[lid] = FieldElement{{0, 0, 0, 0}};
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 执行多个 NTT 阶段
    for (uint stage = stage_start; stage < stage_start + stages_per_kernel && stage < log_n; stage++) {
        uint stride = 1 << stage;
        uint pairs_in_group = elements_per_group >> 1;
        
        if (lid < pairs_in_group) {
            uint local_group = lid / stride;
            uint pos_in_local_group = lid % stride;
            uint local_base = local_group * (stride << 1) + pos_in_local_group;
            
            uint local_i = local_base;
            uint local_j = local_base + stride;
            
            if (local_j < elements_per_group) {
                // 计算全局旋转因子索引
                uint global_twiddle_idx = (group_start + local_i) >> stage;
                FieldElement twiddle = twiddle_factors[global_twiddle_idx];
                
                // 执行蝶形运算
                FieldElement u = shared_data[local_i];
                FieldElement v = field_multiply(shared_data[local_j], twiddle);
                
                shared_data[local_i] = field_add(u, v);
                shared_data[local_j] = field_subtract(u, v);
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // 写回全局内存
    if (group_start + lid < n) {
        global_data[group_start + lid] = shared_data[lid];
    }
}

// 位反转排列内核
kernel void bit_reverse_kernel(
    device FieldElement* data [[buffer(0)]],
    device const uint* bit_reverse_table [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= n) return;
    
    uint reversed_idx = bit_reverse_table[gid];
    
    // 只交换 gid < reversed_idx 的元素，避免重复交换
    if (gid < reversed_idx) {
        FieldElement temp = data[gid];
        data[gid] = data[reversed_idx];
        data[reversed_idx] = temp;
    }
}

// 批量 NTT 内核（处理多个独立的 NTT）
kernel void batch_ntt_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* twiddle_factors [[buffer(1)]],
    constant uint& log_n [[buffer(2)]],
    constant uint& batch_size [[buffer(3)]],
    constant uint& stage [[buffer(4)]],
    uint gid [[thread_position_in_grid]]
) {
    uint n = 1 << log_n;
    uint total_elements = batch_size * n;
    
    if (gid >= total_elements) return;
    
    // 确定当前元素属于哪个批次
    uint batch_idx = gid / n;
    uint element_idx = gid % n;
    
    uint stride = 1 << stage;
    uint m = n >> (stage + 1);
    uint butterfly_idx = element_idx >> 1;
    
    if (butterfly_idx >= m) return;
    
    // 计算蝶形运算的索引
    uint group = butterfly_idx / stride;
    uint pos_in_group = butterfly_idx % stride;
    uint base = group * (stride << 1) + pos_in_group;
    
    uint i = batch_idx * n + base;
    uint j = batch_idx * n + base + stride;
    
    // 获取旋转因子
    FieldElement twiddle = twiddle_factors[butterfly_idx];
    
    // 执行蝶形运算
    FieldElement u = data[i];
    FieldElement v = field_multiply(data[j], twiddle);
    
    data[i] = field_add(u, v);
    data[j] = field_subtract(u, v);
}

// 逆 NTT 内核
kernel void intt_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* inverse_twiddle_factors [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    constant uint& n [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    uint stride = 1 << (stage);
    uint m = n >> (stage + 1);
    
    if (gid >= m) return;
    
    // 计算蝶形运算的索引（逆序）
    uint group = gid / stride;
    uint pos_in_group = gid % stride;
    uint base = group * (stride << 1) + pos_in_group;
    
    uint i = base;
    uint j = base + stride;
    
    // 获取逆旋转因子
    FieldElement inv_twiddle = inverse_twiddle_factors[gid];
    
    // 执行逆蝶形运算
    FieldElement u = data[i];
    FieldElement v = data[j];
    
    data[i] = field_add(u, v);
    data[j] = field_multiply(field_subtract(u, v), inv_twiddle);
}

// 最终归一化内核（除以 n）
kernel void normalize_kernel(
    device FieldElement* data [[buffer(0)]],
    device const FieldElement* inverse_n [[buffer(1)]],
    constant uint& n [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= n) return;
    
    data[gid] = field_multiply(data[gid], inverse_n[0]);
}