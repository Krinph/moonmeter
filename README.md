# moonmeter

**DL/T 645-2007 电能表通信协议栈** for [MoonBit](https://www.moonbitlang.com)：帧编解码、BCD 数据标识、电表模拟器与规约一致性校验器。

moonmeter 是 MoonBit 生态中**首个** DL/T 645（中国多功能电能表通信规约）实现。它把一条真实电表总线上的一次完整抄读闭环搬到代码里：**构造请求帧 → 编码 → 模拟电表应答 → 解码 → 一致性校验**，无需任何硬件即可开发、测试和验证基于该规约的抄表、计费与充电桩系统。

## Features

- 🔤 **帧编解码**：`68H` 起始符、6 字节 BCD 地址域、控制码、双字节长度、数据域、累加和校验（CS）、`16H` 结束符，严格按 DL/T 645-2007 帧格式；
- 🔢 **BCD 编解码**：地址、时间戳与电量读数的 BCD 编解码（低字节在前）；
- 📖 **数据标识（DI）**：常用 DI 定义（组合有功总/尖/峰/平/谷、电压、电流、功率）与请求构造；
- 🧪 **电表模拟器**：`MeterSim` 可注册任意读数并应答读数据请求（0x81 应答帧），也可生成带错误（坏校验/坏结束符）的测试帧流；
- 🔍 **一致性校验器**：把字节流切分为帧并报告 `stray_byte` / `bad_checksum` / `bad_end` / `truncated_frame` 等结构化诊断，用于规约一致性测试；
- 🖥️ **CLI**：`parse` / `validate` / `read` / `simulate` 四个子命令，离线调试无需硬件；
- 📚 **库 + CLI 双层 API**。

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

# 解析一帧
moon run cmd/main -- parse 68 00 01 02 03 04 05 68 01 04 00 00 00 00 00 E4 16

# 生成模拟电表帧流（两个读数）
moon run cmd/main -- simulate

# 校验一段字节流（发现坏帧/坏校验/杂散字节）
moon run cmd/main -- validate 68 00 01 02 03 04 05 68 81 06 00 00 01 00 01 00 01 69 15
#   -> [error @ bad_end] frame does not end with 16H
```

### Library

```moonbit
import "Krinph/moonmeter" @moonmeter

// 1. 构造读请求
let addr : Array[Byte] = [0x00, 0x01, 0x02, 0x03, 0x04, 0x05]
let req = @moonmeter.build_read_request(addr, @moonmeter.di_active_total())

// 2. 模拟电表应答
let sim = @moonmeter.MeterSim::new(addr)
sim.set_reading(@moonmeter.di_active_total(), [0x56, 0x34, 0x12, 0x00])
let reply = sim.answer_read(req)

// 3. 解码应答并读出电量（BCD 低字节在前 -> 1234.56 kWh，0.01 精度）
let frame = @moonmeter.decode_frame(reply).unwrap()
let reading = @moonmeter.parse_reading(frame.data).unwrap()
let raw = @moonmeter.bcd_decode(reading.value)  // 123456

// 4. 一致性校验
let (frames, findings) = @moonmeter.split_frames(stream)
```

## Counting / protocol notes

- 帧长：`1 + 6 + 1 + 1 + 2 + L + 1 + 1 = 13 + L` 字节；
- 校验 CS = 从第一个 `68H` 到数据域末字节的累加和（模 256）；
- 地址域 6 字节 BCD（低字节在前）；数据标识 DI0..DI3 依次置于数据域；
- 应答帧控制码 = `0x80 | 功能码`（如读数据应答 `0x81`）；
- 加密方式（GB/T 32960 类比）不在 DL/T 645 帧内；645 无加密位，本实现覆盖明文帧。

## Development

```text
moon check
moon test      # 13 项测试：帧往返、校验、BCD、命令、模拟器、校验器
moon fmt
```

## License

[Apache-2.0](LICENSE)
