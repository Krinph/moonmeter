# moonmeter

**DL/T 645-2007 电能表通信协议栈** for [MoonBit](https://www.moonbitlang.com)：符合标准的帧编解码、BCD 数据标识、电表模拟器、错误应答解码与规约一致性校验器。

moonmeter 是 MoonBit 生态中**首个** DL/T 645（中国多功能电能表通信规约）实现。它把一次完整抄读闭环搬到代码里：**构造标准请求帧 → 编码 → 模拟电表应答 → 解码 → 格式化 → 一致性校验**，无需硬件即可开发、测试和验证基于该规约的抄表、计费与充电桩系统。

当前版本 `0.2.0`（MVP）：核心协议能力、库 + CLI + 可运行示例、43 项测试与三平台 CI 均已就绪。协议实现严格遵循 DL/T 645-2007 的帧格式、控制码与数据标识定义；逐字节报文案例与符合性边界见 [docs/STANDARD_CONFORMANCE.md](docs/STANDARD_CONFORMANCE.md)。

## Features

- 🔤 **帧编解码**：`68H` 起始符、6 字节 BCD 地址域、控制码、**单字节长度 L**、**+33H 数据域编码**、累加和校验（CS）、`16H` 结束符；
- 🔢 **BCD 编解码与地址校验**：地址、时间戳与电量读数的 BCD 编解码（低字节在前）；12 位地址的合法性校验与字节/字符串互转；
- 📖 **数据标识（DI）目录**：正向有功总/尖/峰/平/谷电能、电压、电流、功率（DI3DI2DI1DI0），附标准名称、单位与小数位；
- ⚠️ **错误应答解码**：把电表的 `0xD1` 异常应答帧解码为结构化错误码（密码错、控制码错、数据标识错、长度错、地址错等）；
- 💡 **电量格式化**：把 BCD 寄存器原始值按 DI 小数位格式化为定点小数（如 `1234.56 kWh`）；
- 💡 **电表模拟器**：`MeterSim` 可注册任意读数并按标准应答读数据请求（`0x91` 应答帧），也可生成带错误（坏校验/坏结束符）的测试帧流；
- 🔍 **一致性校验器**：把字节流切分为帧并报告 `stray_byte` / `bad_checksum` / `bad_end` / `truncated_frame` / `short_read_reply` / `unknown_function` 等结构化诊断；提供一步到位的 `validate_stream` API 与错误/警告计数；
- 🖥️ **CLI**：`parse` / `validate` / `read` / `simulate` 四个子命令，离线调试无需硬件；
- 📚 **库 + CLI + 可运行示例**三层交付。

## 典型使用场景

1. **无硬件抄表开发**：上层系统在开发/CI 中用 `MeterSim` 注册读数并模拟电表标准应答，验证请求构造与读数解析逻辑，避免依赖硬件在环。
2. **规约一致性静态检查**：把协议分析仪抓取的字节流喂给 `validate` / `validate_stream`，自动定位坏校验、错误结束符、非法 BCD、短应答、未定义功能码、杂散字节等问题，作为出厂静态筛查与回归测试的一环。判定范围限于字节流可客观验证的格式与语义规则（见符合性文档 1.2 节）。
3. **充电桩 / 计费系统的数据解析**：把电表上报的 BCD 电量寄存器按 DI 语义标注名称、单位与小数位并定点格式化，直接得到带单位的读数（如 `Forward active total energy = 1234.56 kWh`），供对账使用。

## Install

```text
moon add Krinph/moonmeter
```

## Usage

### CLI

```text
# 构造读"当前正向有功总电能"(DI 00010000)请求帧，地址 123456789012
moon run cmd/main -- --address 129078563412 read
#   -> 68 12 90 78 56 34 12 68 11 04 33 33 34 33 68 16

# 解析标准应答帧（显示地址、控制码、功能码、DI 名称、逻辑数据域）
moon run cmd/main -- parse "68 12 90 78 56 34 12 68 91 08 33 33 34 33 89 67 45 33 54 16"
#   -> control : 0x91 / function: 17 (reply) / di : Forward active total energy

# 校验一段字节流（发现坏帧/坏校验/杂散字节，并汇总错误/警告数）
moon run cmd/main -- validate "68 12 90 78 56 34 12 68 91 06 00 00 01 00 01 00 01 69 15"
```

### Runnable example

完整闭环示例（`build -> simulate -> decode -> format -> validate`）：

```text
moon run cmd/roundtrip
```

输出：

```text
1. build read request
   68 00 01 02 03 04 05 68 11 04 33 33 34 33 C1 16
2. simulate an electricity meter
   68 00 01 02 03 04 05 68 91 08 33 33 34 33 89 67 45 33 AD 16
3. decode and label the reading
   Forward active total energy
4. format the value
   1234.56 kWh
5. validate the wire stream
   1 frame(s), 0 error(s), 0 warning(s)
```

### Library

```moon
import "Krinph/moonmeter" @moonmeter

// 1. 构造读请求（0x11），数据域 DI 00010000 经 +33H 编码
let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())

// 2. 模拟电表应答（0x91）
let sim = @moonmeter.MeterSim::new(addr)
sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
let reply = sim.answer_read(req)

// 3. 解码应答并格式化电量（DI 元数据：2 位小数，kWh）
let frame = @moonmeter.decode_frame(reply.unwrap()).unwrap()
let reading = @moonmeter.parse_reading(frame.data).unwrap()
let info = @moonmeter.di_info(reading.di).unwrap()
let (raw, decimals) = @moonmeter.decode_energy(reading.value, info.decimals)
println(@moonmeter.format_energy(raw, decimals) + " " + info.unit) // 1234.56 kWh

// 4. 一致性校验（一步到位）
let (frames, findings) = @moonmeter.validate_stream(reply.unwrap())
let (errors, warnings) = @moonmeter.count_findings(findings)
```

## Protocol notes

- 帧长：`1 + 6 + 1 + 1 + 1 + L + 1 + 1 = 12 + L` 字节（L 为**单字节**）；
- 数据域**逐字节 +33H** 发送、-33H 接收；CS = 从第一个 `68H` 到数据域末字节（已编码）的累加和模 256；
- 地址域 6 字节 BCD（低字节在前）；数据标识按 DI0,DI1,DI2,DI3 传输（标准书写为 DI3DI2DI1DI0）；
- 控制码：`D7` 方向（0 主站命令 / 1 从站应答）、`D6` 异常、`D5` 后续帧、`D4~D0` 功能码；读数据 `0x11`、正常应答 `0x91`、异常应答 `0xD1`；
- 功能码按标准为离散定义（08H、11H~1BH），非连续编号；
- 645 帧无加密位，本实现覆盖明文帧。完整报文案例见 [STANDARD_CONFORMANCE.md](docs/STANDARD_CONFORMANCE.md)。

## Development

```text
moon check --deny-warn
moon test      # 43 项测试：帧往返、+33H、校验、BCD、地址、DI、命令码、错误应答、格式化、模拟器、校验器、黄金报文
moon fmt --check
moon info      # 公开接口见 pkg.generated.mbti
moon run cmd/roundtrip
```

CI 在 Ubuntu / macOS / Windows 三平台覆盖 check、test、格式与接口检查及 CLI smoke test。

## 与现有工具的关系

DL/T 645 / DL/T 698.45 / DLMS/COSEM 电能计量规约在 MoonBit 生态中无成熟实现；邻近的 Modbus 协议栈与电表数据审计项目不涉及 645 帧格式，定位不同。moonmeter 的增量在于把符合标准的帧编解码、模拟器、错误解码与一致性校验组合成可离线复现的闭环，详见 [申报书](docs/PROJECT_PROPOSAL.md) 与 [标准符合性说明](docs/STANDARD_CONFORMANCE.md)。

## License

[Apache-2.0](LICENSE)
