# 小虾牌 (Shrimp Cards)

<p align="left">
  <a href="./README.md"><img alt="简体中文" src="https://img.shields.io/static/v1?label=%E7%AE%80%E4%BD%93%E4%B8%AD%E6%96%87&message=current&color=0f766e"></a>
  <a href="./README.en.md"><img alt="English" src="https://img.shields.io/static/v1?label=English&message=README&color=64748b"></a>
  <a href="https://www.moonbitlang.com/"><img alt="MoonBit" src="https://img.shields.io/static/v1?label=MoonBit&message=native&color=7c3aed"></a>
  <a href="./LICENSE"><img alt="License: MIT" src="https://img.shields.io/static/v1?label=license&message=MIT&color=22c55e"></a>
  <img alt="terminal-first" src="https://img.shields.io/static/v1?label=terminal&message=first&color=334155">
  <img alt="PvE and PvP" src="https://img.shields.io/static/v1?label=mode&message=PvE%20%2B%20PvP&color=2563eb">
</p>

小虾牌是一个终端优先的 MoonBit 卡牌游戏基础项目，用来支持 PvE 和 PvP
实验。当前代码重点放在玩法以外的基础设施：本地 host/client 通信、实时干预窗口、replay
记录，以及 agent 计划占位流程。

玩法规则目前仍然刻意留空，后续再单独设计。

## 环境要求

- MoonBit 工具链
- 可以同时运行三个 shell 会话的终端

## 检查项目

```sh
moon fmt --check
moon check --target native
moon test --target native
moon test
moon info --target native
```

## 运行本地对局

启动 host：

```sh
moon run cmd/main --target native -- host \
  --port 7777 \
  --match-id local-match \
  --seed 42 \
  --replay-dir replays
```

可选心跳参数：

```sh
--heartbeat-timeout-ms 30000
--heartbeat-scan-ms 1000
```

在第二个终端加入玩家 A：

```sh
moon run cmd/main --target native -- join \
  --name Alice \
  --lang zh \
  --host ws://127.0.0.1:7777/match
```

可选心跳参数：

```sh
--heartbeat-interval-ms 5000
```

在第三个终端加入玩家 B：

```sh
moon run cmd/main --target native -- join \
  --name Bob \
  --lang zh \
  --host ws://127.0.0.1:7777/match
```

玩家终端里可用的监督命令：

```text
/ready
/prefer <text>
/ban <text>
/lock
/leave
/lang zh
/lang en
```

双方玩家都发送 `/ready` 后，对局会打开第一个干预窗口。`/prefer` 和 `/ban`
用于提交监督干预。`/lock` 会关闭当前窗口，生成占位的最终计划，执行一个占位步骤，然后打开下一个窗口。`/leave`
会结束对局并保存 replay。`/lang` 只切换当前客户端的显示语言，不会发送给 host，也不会改变 replay 数据。

## Replay

打印完整事件流：

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --view A \
  --mode events
```

按输入窗口分组打印事件：

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --view A \
  --mode windows
```

打印 replay 元数据：

```sh
moon run cmd/main --target native -- replay \
  --file replays/local-match.json \
  --mode metadata
```

## CI

GitHub Actions 会在推送到 `main` 和创建 pull request 时运行格式检查、native 检查、native 测试、默认测试和生成接口校验。

## 许可证

本项目使用 [MIT License](./LICENSE)。
