# U-Boot 编译器问题记录（Yocto vs Rockchip SDK）

> 本文档记录 meta-fzhub（RK3568, Yocto）编译 U-Boot 时使用的交叉编译器
> 与 Rockchip 原厂 SDK 的差异，以及潜在风险。

## 1. 两个编译器的对比（已实测确认）

| | Yocto（当前 repo） | SDK `./build.sh uboot` |
|---|---|---|
| gcc 命令 | `aarch64-poky-linux-gcc` | `aarch64-rockchip1031-linux-gnu-gcc` |
| **版本** | **GCC 15.3.0** | **GCC 10.3.1** (arm-10.3-2021.07) |
| 来源 | oe-core `gcc-cross-aarch64`（Yocto 自构建） | `prebuilts/gcc/linux-x86/aarch64/gcc-arm-10.3-2021.07...`（SDK 自带） |
| 调用链 | `u-boot.inc` 的 `CROSS_COMPILE=${TARGET_PREFIX}` | `build.sh` → `mk-loader.sh` → `get_toolchain()` → `./make.sh CROSS_COMPILE=...` |

- 两者编译同一份 U-Boot 2017.09 源码，编译器代差约 5 个大版本（10.x → 15.x）。
- 说明：`build.sh` 的 `get_toolchain()` 首选 SDK prebuilts 里的工具链，
  找不到才回退系统 `aarch64-linux-gnu-gcc`（当前系统无此命令）。

## 2. 影响范围（已通过 dumpimage 对比验证）

- 产物 `uboot.img`（FIT）中：
  - **ATF / OP-TEE / FDT 子镜像逐字节一致**——来自 rkbin 预编译二进制 + 相同 dts，不受编译器影响；
  - **仅 U-Boot 主体不同**（SDK 1323784 B vs Yocto 1311480 B，差约 12KB，hash 不同）——编译器不同所致，属预期。

## 3. 潜在风险

### 编译层面（已基本解除）
- GCC 15 新警告被 `-Werror` 拦截 → 已有补丁 `0003-Revert-Makefile-enable-Werror-option.patch`；
- python2/dtc 等兼容 → 已有对应补丁；
- 当前已能成功产出结构正确的 uboot.img。

### 代码生成层面（风险中等，需实测）
- GCC 15 vs 10 的优化策略、指令选择、`-march` 默认行为不同 → 二进制必然不同（预期）；
- 老代码中若存在**未定义行为**（未初始化变量、别名违规、整数溢出等），
  老编译器可能"恰好正确"，新编译器可能优化出不同行为——编译期不一定报错，运行期才暴露。

### 运行时层面（唯一确定的验证方式）
- **编译通过 ≠ 能正常启动**。GCC 15 编的 U-Boot 是否能在板上完成 DDR 初始化、
  正确加载 ATF/OP-TEE、引导内核，必须**实际烧录验证**（串口日志）；
- ATF/OP-TEE 来自 rkbin 预编译（不受影响），但 U-Boot 通过 FDT 与它们交互。

## 4. 结论与建议

- 风险评估：编译/打包 ✅ 已通过；运行稳定性 ⚠️ 中低风险，必须上板实测。
- 建议验证项：
  1. U-Boot 能正常启动；
  2. 能引导内核进系统；
  3. 长时间稳定性测试。
- 若实测有问题，再考虑对策（如把 Yocto 的 `GCCVERSION` 降级，或用 SDK 工具链做外部 toolchain）。
