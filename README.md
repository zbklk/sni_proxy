# SNIProxy 独立联网安装

在你自己的 GitHub 仓库保存程序、配置和安装脚本。安装时不调用原教程作者的配置接口，也不从 XIU2 仓库临时下载程序。

这是自建 DNS 解锁流程的**第三步：安装反代**。前两步是安装 AdGuard Home、用离线生成器生成并应用 DNS 自定义规则。本仓库的一键脚本不会安装 AdGuard Home。

## 安装前确认

1. 通过 SSH 登录要运行反代的服务器。以下命令在服务器终端执行，不是在 Windows PowerShell 中执行。
2. 服务器需要是 Linux，架构为 amd64（x86_64）或 arm64（aarch64），并使用 systemd。常规 Debian / Ubuntu VPS 可以按下文操作；此脚本不适用于 Alpine/OpenRC 或没有 systemd 的容器。
3. 这台服务器本身应具备你所需平台的访问能力。安装反代不会自动改变它的出口 IP 所属地区。
4. TCP 443 需要可用；如果已有网站、其他代理或 AdGuard Home 的 DoH 占用了该端口，先处理冲突。
5. 安装需要访问本仓库的 `raw.githubusercontent.com` 下载地址；依赖安装需要访问系统软件源。

可以先检查系统架构和端口：

```bash
uname -m
sudo ss -ltnp 'sport = :443'
```

第二条如果列出监听进程，说明 TCP 443 已被占用。

## 一键安装

在具备目标平台访问能力的 **Linux amd64 / arm64、systemd 服务器**上执行：

```bash
curl -fsSL https://raw.githubusercontent.com/zbklk/sni_proxy/main/install_standalone.sh -o /tmp/install-sniproxy-standalone.sh && sudo bash /tmp/install-sniproxy-standalone.sh
```

先完整下载成功，再执行。需要 `curl`、`tar`、`sha256sum`、`flock` 和常见系统工具。Debian/Ubuntu 若缺依赖：

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl tar coreutils util-linux
```

如果已经是 root 用户，可把命令中的 `sudo bash` 改为 `bash`。依赖安装命令中的 `sudo` 也可以省略。

如果想先检查安装资源、校验和解压，不修改服务，使用下面这组命令（这是可选检查，不是正式安装）：

```bash
curl -fsSL https://raw.githubusercontent.com/zbklk/sni_proxy/main/install_standalone.sh -o /tmp/install-sniproxy-standalone.sh
bash /tmp/install-sniproxy-standalone.sh --check
```

检查通过后，执行 `sudo bash /tmp/install-sniproxy-standalone.sh` 正式安装。

## 安装完成后怎么用

1. 查看服务状态，正常应显示 `active (running)`：

   ```bash
   sudo systemctl status sniproxy --no-pager
   ```

2. 在服务器防火墙及云厂商安全组中，允许需要使用反代的客户端来源 IP 访问 TCP 443。来源通常是实际访问网站的客户端或代理出口，不一定是 AdGuard Home 服务器的 IP。
3. 打开之前保存的 AdGuard Home 离线规则生成器，填入这台反代服务器的公网 IPv4 或 IPv6。只有实际可用的 IPv6 才填写。
4. 把生成的规则粘贴到 AdGuard Home 的“过滤器 → 自定义过滤规则”，保存并应用。同一批域名的旧重写规则应替换，其他不相关规则保留。
5. 让需要使用解锁的客户端使用这台 AdGuard Home 进行 DNS 解析，再访问目标平台测试。客户端自行使用其他 DoH/DNS 时可能绕过这些规则。

服务显示运行只说明程序启动成功；还需实际访问目标平台，确认出口和配置符合需求。

## 常用管理命令

| 用途 | 命令 |
|---|---|
| 查看状态 | `sudo systemctl status sniproxy --no-pager` |
| 启动 | `sudo systemctl start sniproxy` |
| 停止 | `sudo systemctl stop sniproxy` |
| 重启（修改配置后使用） | `sudo systemctl restart sniproxy` |
| 查看最近日志 | `sudo journalctl -u sniproxy -n 50 --no-pager` |
| 实时查看日志 | `sudo journalctl -u sniproxy -f` |
| 取消开机启动并停止 | `sudo systemctl disable --now sniproxy` |
| 恢复开机启动并启动 | `sudo systemctl enable --now sniproxy` |

实时日志按 `Ctrl+C` 退出查看，不会停止反代服务。

| 文件 | 位置 |
|---|---|
| 程序 | `/root/sniproxy/sniproxy` |
| 服务器实际使用的配置 | `/root/sniproxy/config.yaml` |
| 安装前的备份 | `/root/sniproxy/backups/` |
| systemd 服务文件 | `/etc/systemd/system/sniproxy.service` |

日志由 systemd journal 管理，新入口不写入旧脚本的 `sniproxy.log`。

## 版本固定是什么意思？以后怎么升级？

当前脚本固定安装 **SNIProxy v1.0.7**。即使上游发布新版，重复执行本仓库命令仍会安装 v1.0.7；它不是“自动更新到官方最新版”的命令。如果服务器已手动安装更新的版本，执行本脚本也会将程序替换为 v1.0.7。

固定版本的目的是保留可重复安装的完整资源，即使原作者的网站或仓库关闭也能从自己的仓库下载。它不会自动获得后续版本的新功能和修复。程序版本、域名清单、服务器出口是否能解锁是三个不同的问题。

需要升级时，可以让维护者或助手按下面的步骤更新本仓库：

1. 下载并核对官方新版本的 amd64、arm64 安装包，同时保存对应源码和许可证。
2. 替换 `vendor/` 中的备份，更新 `SHA256SUMS` 并提交资源文件。
3. 把 `install_standalone.sh` 的 `BASE_URL` 固定到新的资源提交，更新两个 `PACKAGE_SHA` 和所有版本说明；默认配置改变时也要更新 `CONFIG_SHA`。
4. 检查两种架构的下载、校验、解压，并在目标 Linux 环境验证安装和服务启动，再发布新入口。
5. 确认仓库已经更新后，在服务器重新执行本文安装命令。脚本会保留现有配置并备份旧程序。

日常使用无需修改这些内容。只改 README 的版本号或只替换一个压缩包并不能完成升级。

## 常见问题

**下载失败：**检查服务器能否访问 `raw.githubusercontent.com`、DNS 和系统时间是否正常。不要忽略下载错误继续安装。

**提示缺少命令：**先运行上面的 Debian / Ubuntu 依赖安装命令。若缺少 `sudo`，用 root 登录并省略 `sudo`。

**启动失败或 443 被占用：**查看 `sudo journalctl -u sniproxy -n 50 --no-pager`，再用上面的 `ss` 命令检查端口。脚本在安装失败后会尝试恢复旧文件及原来的运行状态。

**服务正常但无法访问：**检查客户端使用的 DNS、AdGuard Home 返回的入口 IP、防火墙/安全组、域名是否在反代允许清单内，以及反代服务器本身能否访问目标网站。SNIProxy 服务器必须能解析到网站真实地址，不能解析回自身。

**旧配置没有更新为 583 个域名：**这是保留现有配置的预期行为。新安装才使用内置默认清单；已有服务器如需调整域名，应备份并编辑 `/root/sniproxy/config.yaml` 后重启服务。不要直接用 AdGuard Home 规则文本覆盖 YAML 配置。

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
