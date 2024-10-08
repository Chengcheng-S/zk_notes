## Fiat-Shamir

将交互式零知识证明转换为非交互式零知识证明的技术。它通过将交互过程中的挑战替换为一个基于哈希函数生成的伪随机数，从而消除了与验证者的直接交互，使得证明可以被离线验证。

### 原理：

核心思想利用**哈希函数**的不可预测性和伪随机性，将交互式协议中的挑战步骤变成由证明者自己生成的一个值

#### 交互式zkp的初始设置

1. **承诺阶段（Commitment Phase）**: 证明者生成某些初始值并将其发送给验证者。
2. **挑战阶段（Challenge Phase）**: 验证者生成一个随机挑战，并将其发送给证明者。
3. **响应阶段（Response Phase）**: 证明者根据挑战生成响应，并将其发送给验证者。

#### Fiat-shamir 的转换

1. 在 Fiat-Shamir Heuristic 中，验证者的挑战不再由验证者生成，而是由证明者通过哈希函数生成。
2. 步骤：
   1. prover 生成 承诺C
   2. prover 将C 于公共输入x 一起输入到哈希函数 H 中，生成挑战值e  e=H(x,C)
   3. Prover 根据 ee 计算响应 rr，并将 C 和 r 作为证明提交
   4. 验证者使用C、r 和公开信息来验证证明的正确性。

#### 验证过程

1. 验证者接收到证明后，独立计算挑战 e=H(x,C)，并使用此 e 和 r来验证 C 是否有效。
2. 验证者不需要与证明者交互，只需检查计算的挑战值与证明中的值是否匹配即可。

