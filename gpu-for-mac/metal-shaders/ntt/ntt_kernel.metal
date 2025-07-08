#include <metal_stdlib>
using namespace metal;

// BLS12-381 标量域参数
constant uint64_t MODULUS = 0x73eda753299d7d483339d80809a1d80553bda402fffe5bfeffffffff00000001UL;
constant uint64_t ROOT_OF_UNITY = 0x0000000000000000000000000000000000000000000000000000000000000000UL; // 需要计算实际值

// Montgomery 参数
constant uint64_t R = 0x1824b159acc5056f998c4fefecbc4ff55884b7fa0003480200000001fffffffeUL;
constant uint64_t R_INV = 0x0e0a77c19a07df2f666ea36f7879462e36fc76959f60cd29ac96341c4ffffffbUL;
constant uint64_t N_INV = 0xfffffffeffffffffUL;

// 模运算辅助函数
inline uint64_t add_mod(uint64_t a, uint64_t b) {
    uint64_t sum = a + b;
    return sum >= MODULUS ? sum - MODULUS : sum;
}

inline uint64_t sub_mod(uint64_t a, uint64_t b) {
    return a >= b ? a - b : a + MODULUS - b;
}

// Montgomery 乘法
inline uint64_t mont_mul(uint64_t a, uint64_t b) {
    // 128位乘法结果
    uint64_t lo = a * b;
    uint64_t hi = mulhi(a, b);
    
    // Montgomery 约简
    uint64_t m = lo * N_INV;
    uint64_t carry = 0;
    
    // lo += m * MODULUS
    uint64_t temp = lo + m * MODULUS;
    if (temp < lo) carry = 1;
    
    // hi += m * MODULUS_HI + carry
    uint64_t result = hi + carry;
    
    return result >= MODULUS ? result - MODULUS : result;
}

// 快速模幂运算
uint64_t pow_mod(uint64_t base, uint64_t exp) {
    uint64_t result = R; // Montgomery 形式的 1
    uint64_t base_mont = mont_mul(base, R); // 转换为 Montgomery 形式
    
    while (exp > 0) {
        if (exp & 1) {
            result = mont_mul(result, base_mont);
        }
        base_mont = mont_mul(base_mont, base_mont);
        exp >>= 1;
    }
    
    return mont_mul(result, 1); // 转换回普通形式
}

// 位反转函数
uint bit_reverse(uint x, uint log_n) {
    uint result = 0;
    for (uint i = 0; i < log_n; i++) {
        result = (result << 1) | (x & 1);
        x >>= 1;
    }
    return result;
}

// NTT 蝶形运算核心
kernel void ntt_butterfly_step(
    device uint64_t* data [[buffer(0)]],
    constant uint& step_size [[buffer(1)]],
    constant uint& stage [[buffer(2)]],
    constant uint& log_n [[buffer(3)]],
    constant uint64_t* twiddle_factors [[buffer(4)]],
    uint id [[thread_position_in_grid]]
) {
    uint n = 1 << log_n;
    uint groups_per_stage = n / (step_size * 2);
    
    if (id >= groups_per_stage * step_size) return;
    
    uint group_id = id / step_size;
    uint local_id = id % step_size;
    
    uint i = group_id * step_size * 2 + local_id;
    uint j = i + step_size;
    
    // 获取预计算的旋转因子
    uint twiddle_index = local_id * (1 << (log_n - stage - 1));
    uint64_t omega = twiddle_factors[twiddle_index];
    
    // 蝶形运算
    uint64_t u = data[i];
    uint64_t v = mont_mul(data[j], omega);
    
    data[i] = add_mod(u, v);
    data[j] = sub_mod(u, v);
}

// 位反转重排
kernel void bit_reverse_permutation(
    device uint64_t* data [[buffer(0)]],
    constant uint& log_n [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    uint n = 1 << log_n;
    if (id >= n) return;
    
    uint reversed_id = bit_reverse(id, log_n);
    
    // 只交换 id < reversed_id 的元素，避免重复交换
    if (id < reversed_id) {
        uint64_t temp = data[id];
        data[id] = data[reversed_id];
        data[reversed_id] = temp;
    }
}

// 预计算旋转因子
kernel void precompute_twiddle_factors(
    device uint64_t* twiddle_factors [[buffer(0)]],
    constant uint& log_n [[buffer(1)]],
    uint id [[thread_position_in_grid]]
) {
    uint n = 1 << log_n;
    if (id >= n / 2) return;
    
    // 计算 ω^id，其中 ω 是 n 次单位根
    twiddle_factors[id] = pow_mod(ROOT_OF_UNITY, id);
}

// 逆 NTT 的最后一步：除以 n
kernel void intt_final_division(
    device uint64_t* data [[buffer(0)]],
    constant uint& log_n [[buffer(1)]],
    constant uint64_t& n_inverse [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    uint n = 1 << log_n;
    if (id >= n) return;
    
    data[id] = mont_mul(data[id], n_inverse);
}

// 批量 NTT（处理多个独立的 NTT）
kernel void batch_ntt_butterfly_step(
    device uint64_t* data [[buffer(0)]],
    constant uint& batch_size [[buffer(1)]],
    constant uint& step_size [[buffer(2)]],
    constant uint& stage [[buffer(3)]],
    constant uint& log_n [[buffer(4)]],
    constant uint64_t* twiddle_factors [[buffer(5)]],
    uint3 id [[thread_position_in_grid]]
) {
    uint batch_id = id.z;
    uint local_id = id.x;
    
    if (batch_id >= batch_size) return;
    
    uint n = 1 << log_n;
    uint batch_offset = batch_id * n;
    uint groups_per_stage = n / (step_size * 2);
    
    if (local_id >= groups_per_stage * step_size) return;
    
    uint group_id = local_id / step_size;
    uint thread_in_group = local_id % step_size;
    
    uint i = batch_offset + group_id * step_size * 2 + thread_in_group;
    uint j = i + step_size;
    
    // 获取旋转因子
    uint twiddle_index = thread_in_group * (1 << (log_n - stage - 1));
    uint64_t omega = twiddle_factors[twiddle_index];
    
    // 蝶形运算
    uint64_t u = data[i];
    uint64_t v = mont_mul(data[j], omega);
    
    data[i] = add_mod(u, v);
    data[j] = sub_mod(u, v);
}

// 使用共享内存优化的 NTT
kernel void ntt_shared_memory(
    device uint64_t* global_data [[buffer(0)]],
    constant uint& log_n [[buffer(1)]],
    constant uint64_t* twiddle_factors [[buffer(2)]],
    threadgroup uint64_t* shared_data [[threadgroup(0)]],
    uint tid [[thread_position_in_threadgroup]],
    uint gid [[thread_position_in_grid]],
    uint group_size [[threads_per_threadgroup]]
) {
    uint n = 1 << log_n;
    
    // 加载数据到共享内存
    if (gid < n) {
        shared_data[tid] = global_data[gid];
    } else {
        shared_data[tid] = 0;
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    // 在共享内存中执行 NTT
    for (uint stage = 0; stage < log_n; stage++) {
        uint step_size = 1 << stage;
        uint group_id = tid / step_size;
        uint local_id = tid % step_size;
        
        if (group_id % 2 == 0) {
            uint i = group_id * step_size + local_id;
            uint j = i + step_size;
            
            if (j < group_size) {
                uint twiddle_index = local_id * (1 << (log_n - stage - 1));
                uint64_t omega = twiddle_factors[twiddle_index];
                
                uint64_t u = shared_data[i];
                uint64_t v = mont_mul(shared_data[j], omega);
                
                shared_data[i] = add_mod(u, v);
                shared_data[j] = sub_mod(u, v);
            }
        }
        
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }
    
    // 写回全局内存
    if (gid < n) {
        global_data[gid] = shared_data[tid];
    }
}

// 验证 NTT 结果的辅助函数
kernel void verify_ntt_result(
    device uint64_t* original [[buffer(0)]],
    device uint64_t* ntt_result [[buffer(1)]],
    device uint64_t* intt_result [[buffer(2)]],
    device bool* is_correct [[buffer(3)]],
    uint id [[thread_position_in_grid]],
    uint n [[threads_per_grid]]
) {
    if (id >= n) return;
    
    // 检查 INTT(NTT(x)) == x
    if (original[id] != intt_result[id]) {
        *is_correct = false;
    }
}