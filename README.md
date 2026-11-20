# moonmeter

**DL/T 645-2007 电能表通信协议栈** for [MoonBit](https://www.moonbitlang.com)：帧编解码、BCD 数据标识、电表模拟器、错误应答解码与规约一致性校验器。

moonmeter 是 MoonBit 生态中**首个** DL/T 645（中国多功能电能表通信规约）实现。它把一条真实电表总线上的一次完整抄读闭环搬到代码里：**构造请求帧 → 编码 → 模拟电表应答 → 解码 → 格式化 → 一致性校验**，无需任何硬件即可开发、测试和验证基于该规约的抄表、计费与充电桩系统。

当前版本 `0.2.0`（MVP）：核心协议能力、库 + CLI 双层 API、可运行示例、35 项测试与三平台 CI 均已就绪。

## Features

- 🔤 **帧编解码**：`68H` 起始符、6 字节 BCD 地址域、控制码、双字节长度、数据域、累加和校验（CS）、`16H` 结束符，严格按 DL/T 645-2007 帧格式；
- 🔢 **BCD 编解码与地址校验**：地址、时间戳与电量读数的 BCD 编解码（低字节在前）；12 位地址的合法性校验与字节/字符串互转；
- 📖 **数据标识（DI）目录**：常用 DI 定义（组合有功总/尖/峰/平/谷、电压、电流、功率）与可读名称、单位、小数位；
- ⚠️ **错误应答解码**：把电表返回的 `0xC1` 类错误帧解码为结构化错误码（密码错、控制码错、数据标识错、长度错、地址错等）；
- 💡 **电量格式化**：把 BCD 寄存器原始值格式化为定点小数（如 `1234.56 kWh`）；
- 🧪 **电表模拟器**：`MeterSim` 可注册任意读数并应答读数据请求（`0x81` 应答帧），也可生成带错误（坏校验/坏结束符）的测试帧流；
- 🔍 **一致性校验器**：把字节流切分为帧并报告 `stray_byte` / `bad_checksum` / `bad_end` / `truncated_frame` / `short_read_reply` 等结构化诊断；提供一步到位的 `validate_stream` API 与错误/警告计数；
- 🖥️ **CLI**：`parse` / `validate` / `read` / `simulate` 四个子命令，离线调试无需硬件；
- 📚 **库 + CLI + 可运行示例**三层交付。

## 典型使用场景

1. **无硬件抄表开发**：上层抄表系统在没有真实电表的开发/CI 环境中，用 `MeterSim` 模拟应答，验证请求构造与读数解析逻辑，避免依赖硬件在环。
2. **规约一致性测试**：设备厂商把协议分析仪抓取的字节流喂给 `validate` / `validate_stream`，自动定位坏校验、错误结束符、非法 BCD、短应答等问题，作为出厂检测或回归测试的一环。
3. **充电桩 / 计费系统的数据解析**：把电表上报的 BCD 电量寄存器解码并按 DI 语义标注、定点格式化，直接得到带单位和可读名称的读数（如“Total active energy = 1234.56 kWh”），供计费与账务对账使用。

## Install

```text
moon add Krinph/moonmeter
```

## Usage

### CLI

```text
# 构造一个"读组合有功总电能"请求帧（地址 000102030405）
moon run cmd/main -- read
#   -> 68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16

# 解析一帧（显示地址、控制码、功能码、数据域、DI 名称、错误码）
moon run cmd/main -- parse 68 00 01 02 03 04 05 68 81 08 00 00 00 00 56 34 12 00 04 16
#   -> di : Total active energy

# 生成模拟电表帧流（两个读数）
moon run cmd/main -- simulate

# 校验一段字节流（发现坏帧/坏校验/杂散字节，并汇总错误/警告数）
moon run cmd/main -- validate 68 00 01 02 03 04 05 68 81 06 00 00 01 00 01 00 01 69 15
#   -> [error @ bad_end] frame does not end with 16H
#   -> summary: 1 error(s), 0 warning(s)
```

### Runnable example

完整闭环示例（`build -> simulate -> decode -> format -> validate`）：

```text
moon run cmd/roundtrip
```

输出：

```text
1. build read request
   68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16
2. simulate an electricity meter
   68 00 01 02 03 04 05 68 81 08 00 00 00 00 56 34 12 00 04 16
3. decode and label the reading
   Total active energy
4. format the value
   1234.56 kWh
5. validate the wire stream
   1 frame(s), 0 error(s), 0 warning(s)
```

### Library

```moon
import "Krinph/moonmeter" @moonmeter

// 1. 构造读请求
let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())

// 2. 模拟电表应答
let sim = @moonmeter.MeterSim::new(addr)
sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
let reply = sim.answer_read(req)

// 3. 解码应答并格式化电量
let frame = @moonmeter.decode_frame(reply.unwrap()).unwrap()
let reading = @moonmeter.parse_reading(frame.data).unwrap()
let (raw, decimals) = @moonmeter.decode_energy(reading.value, 2)
println(@moonmeter.format_energy(raw, decimals) + " kWh") // 1234.56 kWh

// 4. 一致性校验（一步到位）
let (frames, findings) = @moonmeter.validate_stream(stream)
let (errors, warnings) = @moonmeter.count_findings(findings)
```

## Counting / protocol notes

- 帧长：`1 + 6 + 1 + 1 + 2 + L + 1 + 1 = 13 + L` 字节；
- 校验 CS = 从第一个 `68H` 到数据域末字节的累加和（模 256）；
- 地址域 6 字节 BCD（低字节在前）；数据标识 DI0..DI3 依次置于数据域；
- 应答帧控制码 = `0x80 | 功能码`（如读数据应答 `0x81`）；错误帧额外置 `0x40`（如 `0xC1`）；
- 加密方式（GB/T 32960 类比）不在 DL/T 645 帧内；645 无加密位，本实现覆盖明文帧。

## Development

```text
moon check --deny-warn
moon test      # 35 项测试：帧往返、校验、BCD、地址、DI、命令、错误应答、格式化、模拟器、校验器
moon fmt --check
moon info      # 公开接口见 pkg.generated.mbti
moon run cmd/roundtrip
```

CI 在 Ubuntu / macOS / Windows 三平台覆盖 check、test、格式与接口检查及 CLI smoke test。

## 与现有工具的关系

DL/T 645 / DL/T 698.45 / DLMS/COSEM 电能计量规约在 MoonBit 生态中无成熟实现；邻近的 Modbus 协议栈与电表数据审计项目不涉及 645 帧格式，定位不同。moonmeter 的增量在于把帧编解码、模拟器、错误解码与一致性校验组合成可离线复现的闭环，详见 [申报书](docs/PROJECT_PROPOSAL.md)。

## License

[Apache-2.0](LICENSE)
