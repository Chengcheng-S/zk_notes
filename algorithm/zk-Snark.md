## ZK-Snark

https://learnblockchain.cn/article/1662

zk-snark (zero knowledge succinct non interactive arguments of knowledge) 零知识证明简洁非交互知识论证。

> **所谓的*非交互只不过是把verifier 选择随机数的工作交给了「可信设置」来完成，也就是由一个可信任的第三方在证明开始前选择随机挑战点x*。**
>
> **这种改变对prover 没什么影响，因为他需要的始终是一组与x 相关的加密值，而不用管这些加密值来自verifier，还是来自可信第三方。但这种改变对verifier 有影响，因为他本来知道x，可以用x 计算t(x)，但现在他不知道了。**

所以从交互到非交互，最主要的改变就是要**在可信设置中把t(x)给到verifier，以便他能完成验证工作。**

zk-SNARK是非交互的（**non interactive**），它是通过**可信设置**（`Trusted Setup Ceremony`）将验证者的**挑战参数**以**同态加密**的形式**隐藏**起来，变成**公共参数**，**所有验证者都可以用这些参数做计算从而省掉了交互过程**。**简洁性**（succinct）指生成的**证明很小**，适合链上**存储和验证**。

流程：

1. **statement**：  证明的目标和业务阐述
2. **computation**：基于目标和业务逻辑抽象出的计算逻辑
3. **Airthmetic Circuits**： 算数电路，描述计算约束的高级语言程序
4. **R1CS**： 将电路转换成一阶约束系统（Rank-1 constraint system）
5. **QAP**：将R1CS 转换成多项式（quardatic arithmetic program）
6. **setup**：设置加密的参数，包括公共挑战参数等
7. **prove**：生成证明 proof
8. **verify**：验证proof

要完成zk-SNARK系统，需要处理两个核心任务：

- 将问题转化成多项式
- 构建多项式的证明系统。



zk-SNARK 协议需要证明的多项式是A(x) * B(x)–C(x)，如果把p(x)还原为A(x) * B(x)–C(x)，相较于p(x)时的协议，主要区别在于：

- prover 需要分别提供A(s)、B(s)、C(s)的加密值；
- verifier 需要验证**A(s) * B(s) = h(s) * t(s)+ C(s)；**
- 在对prover 的计算进行约束时（比如必须用s 计算），需要有3 个不同的α 分别对应于A(s)、B(s)、C(s)；当prover 对计算结果加密时，需要有3 个不同的δ分别加密A(s)、B(s)、C(s)。



零知识证明中的Challenge。**验证者通过本地随机数产生一个挑战（Challenge），将这个随机产生的挑战值发给证明者，证明者需要真的有知识才能以大概率做出通过验证者的响应**。



大多数 SNARK 后端都会让证明者使用[多项式承诺方案](https://cacr.uwaterloo.ca/techreports/2010/cacr2010-10.pdf)密码学地承诺电路中每个门的值。然后证明者去证明承诺值确实对应于证据检查程序的正确执行。多项式承诺方案部分的证明者工作称为**承诺开销**。SNARK 具有来自多项式承诺方案以外的额外证明者开销，但承诺开销往往是瓶颈所在



> 多项式IOP（Polynomial Interactive Oracle Proofs）是一种交互式证明，其中一部分证明者的消息不被验证者完全阅读。在标准IOP中，每个特殊消息都是一个字符串，并且验证者被赋予对字符串中单个符号的查询访问权限。多项式IOP是一种更有效的接近性测试方法，测试一个点的集合大部分是在一个度小于某个值的多项式上，能达到线性级的证明复杂度和对数级的验证复杂度。
>
> 多项式承诺（Polynomial Commitment）是密码学中的一个概念，它在零知识证明等领域有着重要应用34。在一个多项式承诺方案中，证明者计算一个多项式的承诺，并可以在多项式的任意一点进行打开，该承诺方案能证明多项式在特定位置的值与指定的值一致。这种方法可以以更灵活和有效的方式来表示证明的约束
>
> ，一个多项式IOP是一种交互式协议，在一个或多个轮中，证明者可以向验证者“发送”一个非常大的多项式g。因为g太大了，所以人们不希望有验证者 来阅读对g的完整描述。相反，在任何有效的多项式IOP中，验证者只在一点（或少数点）“查询”g。这意味着唯一的信息是验证者ne 关于g的广告来检查证明者的行为是否诚实是对g的一个（或几个）评估。
>
> 反过来，一个多项式承诺方案使一个不可信的证明者能够简洁地提交一个多项式g，然后提供给验证者所选择的点r的任何求值g (r)， 并证明返回的值确实与已提交的多项式一致。本质上，多项式承诺方案正是人们需要获得的密码原语 从一个多项式的IOP中得到一个简洁的论证。而不是让证明器像在多项式IOP中那样向验证器发送一个大的多项式g，而是让参数系统证明器代替密码co 首先到g，然后揭示验证者执行检查所需的g的任何评估.
