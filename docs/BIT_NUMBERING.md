# DBC 位编号

依据 Kvaser CANlib 的公开说明，DBC 的位编号是 sawtooth。以下标号均为 payload 位坐标，字节内的 0 是最低有效位。

```text
             MSB                          LSB
byte 0        7   6   5   4   3   2   1   0
byte 1       15  14  13  12  11  10   9   8
byte 2       23  22  21  20  19  18  17  16
```

Intel（@1）的 start bit 是信号的 LSB。每读一位，payload 坐标加一，raw 权重从 2⁰ 起递增。例如 start=2、length=9：

```text
byte 0       r5  r4  r3  r2  r1  r0   .   .
byte 1        .   .   .   .   .  r8  r7  r6
raw 0x12F -> payload BC 04（人工推导）
```

Motorola（@0）的 start bit 是信号的 MSB。字节内向低坐标移动，遇到 bit 0 后跳到下一字节的 bit 7，即坐标加 15。每读一位，raw 累加值左移一位。start=2、length=5：

```text
byte 0        .   .   .   .   .  r4  r3  r2
byte 1       r1  r0   .   .   .   .   .   .
positions = 2,1,0,15,14
raw 0x15 -> payload 05 40（人工推导）
```

字节对齐的 Motorola start=7、length=16：

```text
byte 0      r15 r14 r13 r12 r11 r10  r9  r8
byte 1       r7  r6  r5  r4  r3  r2  r1  r0
raw 0x1234 -> payload 12 34
```

start=0 并不意味着字节对齐，Motorola start=0、length=9：

```text
byte 0        .   .   .   .   .   .   .  r8
byte 1       r7  r6  r5  r4  r3  r2  r1  r0
raw 0x1AB -> payload 01 AB
```

有符号信号在抽取完成后解释补码。12-bit raw=0xFFF 的符号位为 2¹¹，符号扩展后为 -1；不可直接忽略宽度而 cast。64-bit 信号单独处理，避免对 64 位整数移位 64 次。

每个信号先生成最多 64 个合法坐标；布局、边界校验、重叠检查和编解码共享这个坐标语义。测试既使用人工位图，也将用外部工具验证，不只依靠自编自解。

参考：https://kvaser.com/canlib-webhelp/group__kvadb__signals.htm
