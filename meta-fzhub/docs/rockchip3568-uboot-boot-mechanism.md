# Rockchip U-Boot 启动与镜像加载机制 —— 学习笔记

> 主题：在 Rockchip 原厂方式（MiniLoaderAll + uboot.img + boot.img）下，
> U-Boot 如何找到并加载 boot.img？以及分区表（GPT / parameter）在其中扮演的角色。

---

## 0. 一句话总览

**U-Boot 不是靠"烧死的固定地址"找 boot.img，而是：动态检测启动设备 → 读取介质上的分区表（GPT 或 parameter/mtdparts）→ 按分区名 `"boot"` 找到分区 → 把 boot.img 读进内存 → `booti` 启动内核。**

---

## 1. 完整启动链（全景图）

```
┌──────────┐  加载   ┌──────────────────┐   执行   ┌─────────────────┐
│  BootROM │ ──────► │  MiniLoaderAll    │ ──────► │ DDR init(FlashData)│
│ (固化)    │  64扇区 │  = idbloader      │         └─────────────────┘
└──────────┘         │  FlashHead头       │                │
                     │  FlashData(DDR)    │                ▼
                     │  FlashBoot(SPL)    │  执行   ┌─────────────────┐
                     └──────────────────┘ ──────► │  SPL (FlashBoot) │
                                                  └─────────────────┘
                                                         │ 读 8MB 处 uboot.img
                                                         ▼
                                              ┌──────────────────────┐
                                              │ uboot.img = FIT 镜像  │
                                              │ (uboot/atf-1~6/optee/fdt)│
                                              └──────────────────────┘
                                                         │ SPL 解析 FIT，加载到各自地址
                                                         ▼
                                              ATF(bl31) → 拉起 OP-TEE(bl32) → 切 U-Boot(bl33)
                                                         │
                                                         ▼
                                              U-Boot 执行 bootcmd → bootrkp/boot_fit
                                                         │
                                                         ▼
                                              从 boot/kernel 分区加载 boot.img → booti 启动内核
```

**关键事实**：
- **MiniLoaderAll.bin 是"容器"**：`FlashHead`(头) + `FlashData`(DDR init) + `FlashBoot`(SPL)。BootROM 只认 64 扇区位置。
- **是 SPL 解析 FIT**（`CONFIG_SPL_LOAD_FIT=y`），不是 U-Boot proper——U-Boot 自己还没被加载执行，不可能解析 FIT。
- **ATF/OP-TEE 是 rkbin 预编译二进制**，与编译器无关（所以 SDK 和 Yocto 的 optee 子镜像逐字节一致）。

---

## 2. 核心问题：U-Boot 如何知道去哪加载 boot.img？

### 2.1 启动设备检测 —— `RKIMG_DET_BOOTDEV`（rockchip-common.h）

```bash
rkimg_bootdev="
  if mmc dev 1 && rkimgtest mmc 1; then setenv devtype mmc; setenv devnum 1;   # SD 卡
  elif mmc dev 0; then setenv devtype mmc; setenv devnum 0;                    # eMMC
  elif mtd_blk dev 0; ... elif rknand dev 0; ... elif rksfc dev 1; ..."
```

按优先级**试探** SD → eMMC → NAND → SPI，找到可用介质并设 `devtype/devnum`。

**`if mmc dev 1 && rkimgtest mmc 1; then` 逐句拆解**：

| 片段 | 作用 |
|---|---|
| `mmc dev 1` | 切到 mmc 1 号设备（0=eMMC，1=SD）。**没插 SD 卡则失败（非 0）** |
| `&&` | 短路与，前一条成功才执行后一条 |
| `rkimgtest mmc 1` | 从 mmc 1 的**第 64 扇区**读 2 块，检查 magic `0xFCDC8C3B`（Rockchip IDB loader 标志） |

**语义**：SD 卡存在且 64 扇区烧了 Rockchip loader → 从 SD 启动；否则回退 eMMC。
> 这就是为什么 MiniLoaderAll 必须烧在 64 扇区——U-Boot 靠它判断"这是不是 Rockchip 启动盘"。

### 2.2 默认启动命令链 —— `RKIMG_BOOTCOMMAND`

```c
"boot_android ${devtype} ${devnum};"   // ① Android boot.img 格式
"boot_fit;"                            // ② 标准 FIT (fitImage) 格式
"bootrkp;"                             // ③ Rockchip 传统 .img 格式
"run distro_bootcmd;"                  // ④ 通用 distro 兜底
```

> ⚠️ **`U_BOOT_CMD(bootrkp, ...)` 只是注册命令**，不是设置默认启动！
> 默认启动命令是编译期 `CONFIG_BOOTCOMMAND`（= RKIMG_BOOTCOMMAND）。`U_BOOT_CMD` 只是让 bootrkp 在 shell 里可用、让 bootcmd 能调到它。

### 2.3 `bootrkp` 加载 boot.img —— `cmd/bootrkp.c`

```c
static int do_boot_rockchip(...) {
    dev_desc = rockchip_get_bootdev();                    // ① 选中的启动设备
    part_name = PART_BOOT;                                // "boot"
    part_get_info_by_name(dev_desc, part_name, &part);    // ② 按 GPT 分区名找 "boot"
    return boot_rockchip_image(dev_desc, &part);
}

static int boot_rockchip_image(...) {
    part_get_info_by_name(dev_desc, PART_KERNEL, &kernel_part);  // 找 "kernel" 分区
    read_rockchip_image(dev_desc, &kernel_part, kernel_addr_r);  // 读 kernel.img → 内存
    read_rockchip_image(dev_desc, boot_part, ramdisk_addr_r);    // 读 boot.img → 内存
    rockchip_read_dtb_file(fdt_addr_r);                          // 从 resource.img 取 dtb
    run_command("booti <kernel_addr> <ramdisk> <fdt_addr>", 0);  // 启动
}
```

分区名定义（`include/boot_rkimg.h`）：`PART_BOOT="boot"`、`PART_KERNEL="kernel"`、`PART_MISC="misc"`。

**三个加载约束**（boot.img 不能随便放）：
1. 必须在**名为 `"boot"` 的 GPT 分区**里（按名查，不是按地址）
2. **必须是 Rockchip 镜像格式**（`read_rockchip_image` 检查 `tag != TAG_KERNEL` 就报错）
3. 介质上的**分区表必须包含 boot 分区**

---

## 3. `boot_fit` —— 标准 FIT 格式，不是 Rockchip 专属

`cmd/bootfit.c` 的关键实现：

```c
do_boot_fit_storage() → fit_image_load_bootables()   // 从存储加载 FIT
fdt_check_header(fit)                                 // 检查 FIT 头（FIT 本质是 DTB）
do_bootm_states(..., &images, 1)                      // 标准 bootm 流程
```

- `fdt_check_header` + `do_bootm_states` 是**标准 U-Boot FIT 启动路径** → boot_fit 加载的是**标准 fitImage**
- 它**不是**启动 boot.img（那是 boot_android / bootrkp 的事）
- Rockchip 只做了存储加载（`fit_image_load_bootables` 用 `rockchip_get_bootdev`）和预处理

### 三种内核镜像格式对比

| 格式 | 启动命令 | 内容 | 打包工具 |
|---|---|---|---|
| **Android boot.img** | `boot_android` | header + kernel + ramdisk + dtb | `mkbootimg` |
| **标准 FIT (fitImage)** | `boot_fit` | DTB 结构，kernel/dtb/ramdisk 子镜像 + hash | `mkimage -f` |
| **Rockchip 传统 .img** | `bootrkp` | kernel.img + boot.img(ramdisk) + resource.img(dtb) | Rockchip 工具 |

---

## 4. 分区表机制（GPT / parameter / mtdparts）

### 4.1 GPT 表不是固化在芯片上

| | 说明 |
|---|---|
| GPT 表存哪 | **存储介质上**（eMMC/SD）的 LBA 1 起始扇区（磁盘末尾有备份 GPT） |
| 谁写入 | 烧录时（`gpt write` / `rkdeveloptool` / wic） |
| 芯片有吗 | **没有**。BootROM 只有固化代码（按 64 扇区加载 idbloader） |
| 谁读 | U-Boot 每次启动从当前介质读（`part_get_info_by_name` 背后就是读 LBA 1） |

**结论**：分区表属于"介质内容"，不是"芯片属性"。换一张没烧分区表的卡就启动不了。

### 4.2 GPT 表由开发者定义（三种来源）

| 来源 | 位置 | 用于 |
|---|---|---|
| **parameter 文件** | `parameter_gpt.txt`（SDK 自带） | **RKDevTool / rkdeveloptool 分步烧录** |
| **PARTS_RKIMG / PARTS_DEFAULT 宏** | U-Boot `rockchip-common.h` | U-Boot 内 `gpt write` |
| **`.wks` 文件** | wic 镜像（`bootloader --ptable gpt`） | wic 整体镜像 |

### 4.3 `PARTS_RKIMG` 宏详解（GPT 分区表模板）

```c
"name=uboot,  start=8MB, size=4MB, uuid=${uuid_gpt_loader2};"   // loader2: uboot.img
"name=trust,  size=4M,   uuid=${uuid_gpt_atf};"
"name=resource,size=16MB,uuid=${uuid_gpt_resource};"            // resource.img: dtb/logo
"name=kernel, size=32M,  uuid=${uuid_gpt_kernel};"              // kernel.img
"name=boot,   size=32M,  bootable, uuid=${uuid_gpt_boot};"      // boot.img
...
"name=userdata, size=-,  uuid=${uuid_gpt_userdata};"            // size=- 占满剩余
```

- `name=` 分区名（**U-Boot 按名查的关键**）
- `start=` 起始偏移（首个分区给，后续自动接续）；`size=-` 占满剩余
- `uuid=` 分区类型 GUID（变量引用）

### 4.4 修改分区表能否自由决定镜像烧录地址？

**部分可以**，有两个"不能动"的硬约束：

| 分区 | 固定位置 | 原因 |
|---|---|---|
| **loader1**（MiniLoaderAll/idbloader） | **64 扇区（32KB）** | **BootROM 固化**，芯片出厂就按 64 扇区加载 |
| **loader2**（uboot.img） | **8MB（16384 扇区）** | **SPL 约定**读取位置（`PARTS_RKIMG` 的 `start=8MB`、wks 的 `--offset 16384s`） |

**从 trust 往后**（kernel/boot/resource/rootfs）的偏移和大小**你可以自由排布**——U-Boot 按分区名查，偏移由分区表决定。

> ⚠️ **存储偏移 ≠ 内存地址**：分区表决定镜像在介质上的位置；`kernel_addr_r`/`fdt_addr_r` 环境变量决定 U-Boot 把镜像读到内存的地址。两个独立层面。

---

## 5. parameter 文件机制（与 GPT 的对比）

**parameter 文件会烧到介质固定位置，U-Boot 启动时读它解析 mtdparts。**

证据（`rkflash.sh`）：
```bash
PARAMETER=$ROCKDEV_DIR/parameter.txt
$UPGRADETOOL di -p $PARAMETER    # "download parameter"：烧 parameter 进介质
```

parameter 文件内容（`parameter_gpt.txt`）：
```
FIRMWARE_VER: 6.0.0
MACHINE_MODEL: RK3399
CMDLINE: mtdparts=rk29xxnand:0x...@0x00000040(loader1),
        0x...@0x00002000(loader2),
        0x...@0x00006000(atf),
        0x...@0x00008000(boot:bootable),
        -@0x0040000(rootfs)
```

**`CMDLINE: mtdparts=...` 就是给 U-Boot 解析的分区定义**——U-Boot 从固定位置读 parameter，解析 mtdparts 得到分区布局。

### 两套分区机制对比

| | **parameter/mtdparts 方案**（你 SDK 用的） | **GPT 方案**（PARTS_RKIMG / wic） |
|---|---|---|
| 分区定义存哪 | parameter 文件，**烧在介质固定位置** | **GPT 分区表**，在 LBA 1 |
| 谁写入 | `rkdeveloptool di -p parameter.txt` | `gpt write` / wic 整体镜像 |
| U-Boot 怎么读 | 从固定位置读 parameter → 解析 mtdparts | 读 LBA 1 GPT → `part_get_info_by_name` |
| 修改方式 | 改 parameter 再烧 | 改分区表再写 |

**要点**：PC 端用的 parameter 和烧进介质的必须是同一份；`boot` 分区名要和 U-Boot 的 `PART_BOOT="boot"` 一致；loader1/loader2 约定位置不能动。

---

## 6. 关键概念速查表

| 概念 | 一句话 |
|---|---|
| MiniLoaderAll.bin | idbloader 容器 = FlashHead + FlashData(DDR) + FlashBoot(SPL)，BootROM 从 64 扇区加载 |
| 谁解析 uboot.img(FIT) | **SPL**（`CONFIG_SPL_LOAD_FIT=y`），不是 U-Boot proper |
| 执行顺序 | ATF(bl31) → OP-TEE(bl32) → U-Boot(bl33)，ARM TF-A 规范固定 |
| 加载地址谁定 | FIT 配置（来自 RK3568TRUST.ini 的 ADDR） |
| bootrkp 找 boot.img | `rockchip_get_bootdev()` + 按 GPT 分区名 `"boot"` 查 + 读进 `ramdisk_addr_r` |
| boot_fit | **标准 fitImage** 启动（不是 boot.img） |
| GPT 表 | 介质上 LBA 1，开发者定义，烧录时写入，**芯片里没有** |
| parameter | 烧介质固定位置，U-Boot 读它解析 mtdparts |
| 不能动的分区 | loader1(64扇区)、loader2(8MB)——BootROM/SPL 约定 |
| 存储偏移 vs 内存地址 | 分区表管存储位置；`kernel_addr_r` 等环境变量管内存位置 |

---

## 7. 常见误解澄清

1. ❌ "U-Boot 解析 uboot.img(FIT)" → ✅ **SPL** 解析（U-Boot 自己没被加载执行）
2. ❌ "boot_fit 是启动 boot.img 的" → ✅ boot_fit 启动**标准 fitImage**；boot.img 由 boot_android/bootrkp 处理
3. ❌ "U_BOOT_CMD 设置默认启动命令" → ✅ 它只是注册命令；默认是 `CONFIG_BOOTCOMMAND`
4. ❌ "GPT 表固化在芯片上" → ✅ 存在存储介质，随介质走
5. ❌ "boot.img 随便放哪都能加载" → ✅ 必须放在名为 `boot` 的分区 + Rockchip 格式 + 分区表有它
6. ❌ "改分区表可以随便移动所有镜像" → ✅ 只有 trust 之后的分区可自由；loader1/loader2 固定

---

*整理自：Rockchip rk3568 U-Boot 2017.09 源码分析（bootrkp.c / bootfit.c / rkimgtest.c / rockchip-common.h）+ SDK 烧录流程（rkflash.sh / parameter_gpt.txt）*
