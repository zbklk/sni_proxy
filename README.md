# SNIProxy 独立联网安装

在你自己的 GitHub 仓库保存程序、配置和安装脚本。安装时不调用原教程作者的配置接口，也不从 XIU2 仓库临时下载程序。

## 一键安装

在具备目标平台访问能力的 **Linux amd64 / arm64、systemd 服务器**上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/zbklk/sni_proxy/main/install_standalone.sh -o /tmp/install-sniproxy-standalone.sh && sudo bash /tmp/install-sniproxy-standalone.sh
```

先完整下载成功，再执行。需要 `curl`、`tar`、`sha256sum`、`flock` 和常见系统工具。Debian/Ubuntu 若缺依赖：

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl tar coreutils util-linux
```

只检查安装资源、校验和解压，不修改服务：

```bash
bash /tmp/install-sniproxy-standalone.sh --check
```

## 安装行为

- 固定备份版本 **v1.0.7**，amd64、arm64 安装包 SHA-256 已与官方发布摘要比对。
- 下载地址固定到本仓库的提交，避免安装过程中不同版本混用；安装包和默认配置还会校验 SHA-256。
- 安装目录 `/root/sniproxy`，新安装使用默认配置的 **583 个域名**，监听 TCP 443。
- 已有 `/root/sniproxy/config.yaml` 时保留，避免覆盖个人配置；程序、配置和已有服务文件会备份到 `/root/sniproxy/backups/`。
- 下载和校验完成后才停止旧服务。安装或启动失败会尝试恢复备份；强制关机、kill -9 等无法捕获的中断不保证自动恢复。
- 安装后开机自启。日志写入 systemd journal，通过 `journalctl -u sniproxy -f` 查看。
- 不修改防火墙或 DNS 设置；需要自行限制反代访问来源并确保 TCP 443 未被其他服务占用。若 AdGuard Home 同机使用 DoH，也要避免 443 端口冲突。
- SNIProxy 所在服务器的 DNS 必须能查到目标网站真实地址，不能把目标域名再次解析回反代自身。

## 与 AdGuard Home 配合

AdGuard Home 离线规则生成器填入这台 **SNIProxy 服务器的 IP**。AdGuard Home 重写 DNS，SNIProxy 转发 HTTPS 流量。生成器已备份的域名与新安装默认配置的域名一致。

入口服务器的出口条件决定实际访问能力；安装成功不代表所有平台解锁成功。域名清单是 2026-09-07 的快照。

## 仓库文件

- `install_standalone.sh`：推荐的新独立安装入口。
- `default-config.yaml`：新安装默认使用的配置。
- `vendor/`：固定版本的两个安装包、对应源码、许可证及摘要。
- 原有 `install_sniproxy.sh`、`config.yaml` 保留，旧入口仍依赖上游下载；请使用本文新命令。

更新域名时，可编辑服务器 `/root/sniproxy/config.yaml` 后运行 `sudo systemctl restart sniproxy`。修改仓库默认配置后，还需更新新安装脚本的固定提交与配置摘要。不会自动覆盖已安装服务器的配置。

## 来源与许可证

程序：https://github.com/XIU2/SNIProxy （GPL-3.0），对应源码及许可证已保存在 `vendor/`，无需依赖原仓库获取本次备份源码。

域名快照：https://dnsconfig.072899.xyz/ 2026-09-07 全选输出。新安装脚本为独立实现；原有文件保留。
