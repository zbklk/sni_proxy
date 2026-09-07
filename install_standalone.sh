#!/usr/bin/env bash
# Standalone installer for zbklk/sni_proxy. Assets are pinned to an immutable commit.
set -Eeuo pipefail
umask 077
BASE_URL='https://raw.githubusercontent.com/zbklk/sni_proxy/9a294f2164859e18699f1c8f91d13f195c2a6dde'
INSTALL_DIR='/root/sniproxy'
UNIT='/etc/systemd/system/sniproxy.service'
CONFIG_SHA='bd971bb2646e82490479d2e0f013e4a571efbf807c2e5913e2ffb78f5ff7654b'
CHECK_ONLY=0
case "${1:-}" in
  --check) CHECK_ONLY=1 ;;
  '') ;;
  *) echo 'Usage: bash install_standalone.sh [--check]' >&2; exit 2 ;;
esac
fail() { echo "[ERROR] $*" >&2; exit 1; }
[[ "$(uname -s)" == Linux ]] || fail '需要 Linux 系统。'
for cmd in curl tar sha256sum mktemp install cp mv rm grep sleep; do
  command -v "$cmd" >/dev/null || fail "缺少依赖 $cmd，请先安装。"
done
if (( ! CHECK_ONLY )); then
  [[ $EUID -eq 0 ]] || fail '请使用 sudo bash 运行。'
  command -v systemctl >/dev/null || fail '需要 systemd。'
  [[ -d /run/systemd/system ]] || fail '当前系统未运行 systemd。'
  command -v flock >/dev/null || fail '需要 flock（通常在 util-linux 软件包中）。'
  exec 9>/run/lock/sniproxy-standalone.lock
  flock -n 9 || fail '另一个安装进程正在运行。'
  [[ ! -L "$INSTALL_DIR" && ! -L "$UNIT" ]] || fail '安装目录或服务文件是符号链接，请先人工检查。'
fi
case "$(uname -m)" in
  x86_64|amd64) ARCH=amd64; PACKAGE_SHA='57e322721a8d8bdce8319d0a6643c949e739eccebce627bc60baf38e97236e62' ;;
  aarch64|arm64) ARCH=arm64; PACKAGE_SHA='4c010f44ae1999e5b67db2512b5b33e8465fe2a300d7320e8c8ae76226de7792' ;;
  *) fail '仅支持 Linux amd64 / arm64。' ;;
esac
TMP=$(mktemp -d)
MUTATING=0
WAS_ACTIVE=0
WAS_ENABLED=0
HAD_UNIT=0
HAD_BINARY=0
HAD_CONFIG=0
BACKUP=''
cleanup() {
  rc=$?
  trap - EXIT INT TERM
  set +e
  if (( rc != 0 && MUTATING )); then
    echo "[ERROR] 安装未完成，正在恢复；备份：$BACKUP" >&2
    systemctl stop sniproxy.service
    if (( HAD_BINARY )); then cp -p "$BACKUP/sniproxy" "$INSTALL_DIR/sniproxy"; else rm -f "$INSTALL_DIR/sniproxy"; fi
    if (( HAD_CONFIG )); then cp -p "$BACKUP/config.yaml" "$INSTALL_DIR/config.yaml"; else rm -f "$INSTALL_DIR/config.yaml"; fi
    if (( ! WAS_ENABLED )); then systemctl disable sniproxy.service; fi
    if (( HAD_UNIT )); then cp -p "$BACKUP/sniproxy.service" "$UNIT"; else rm -f "$UNIT"; fi
    systemctl daemon-reload
    if (( WAS_ENABLED )); then systemctl enable sniproxy.service; fi
    if (( WAS_ACTIVE )); then systemctl start sniproxy.service || echo '[ERROR] 旧服务恢复启动失败，请检查 journalctl -u sniproxy。' >&2; fi
  fi
  rm -rf -- "$TMP"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
fetch() { curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 15 --max-time 180 --retry 3 "$1" -o "$2"; }
verify() { printf '%s  %s\n' "$1" "$2" | sha256sum -c -; }
echo "[INFO] 下载已备份的 SNIProxy v1.0.7 ($ARCH)，仅访问 zbklk/sni_proxy。"
fetch "$BASE_URL/vendor/sniproxy_linux_${ARCH}.tar.gz" "$TMP/program.tar.gz"
verify "$PACKAGE_SHA" "$TMP/program.tar.gz"
fetch "$BASE_URL/default-config.yaml" "$TMP/config.yaml"
verify "$CONFIG_SHA" "$TMP/config.yaml"
# Extract only the named executable from the verified official archive.
tar -xzf "$TMP/program.tar.gz" -C "$TMP" --strip-components=1 "sniproxy_linux_${ARCH}/sniproxy"
[[ -f "$TMP/sniproxy" && ! -L "$TMP/sniproxy" ]] || fail '安装包缺少可执行文件。'
if (( CHECK_ONLY )); then
  echo '[OK] 下载、SHA-256 校验和解压通过。未安装、未修改服务。'
  exit 0
fi
chmod 755 "$TMP/sniproxy"
"$TMP/sniproxy" -v
# Finish all downloads and compatibility checks before touching a running service.
install -d -m 700 "$INSTALL_DIR" "$INSTALL_DIR/backups"
for path in "$INSTALL_DIR/sniproxy" "$INSTALL_DIR/config.yaml"; do
  [[ ! -L "$path" ]] || fail "拒绝覆盖符号链接：$path"
done
BACKUP=$(mktemp -d "$INSTALL_DIR/backups/install.XXXXXXXX")
if [[ -f "$INSTALL_DIR/sniproxy" ]]; then cp -p "$INSTALL_DIR/sniproxy" "$BACKUP/sniproxy"; HAD_BINARY=1; fi
if [[ -f "$INSTALL_DIR/config.yaml" ]]; then cp -p "$INSTALL_DIR/config.yaml" "$BACKUP/config.yaml"; HAD_CONFIG=1; fi
if [[ -f "$UNIT" ]]; then cp -p "$UNIT" "$BACKUP/sniproxy.service"; HAD_UNIT=1; fi
if systemctl is-active --quiet sniproxy.service; then WAS_ACTIVE=1; fi
if systemctl is-enabled --quiet sniproxy.service; then WAS_ENABLED=1; fi
cat > "$TMP/sniproxy.service" <<'UNIT_EOF'
[Unit]
Description=SNIProxy (standalone backup)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/root/sniproxy
ExecStart=/root/sniproxy/sniproxy -c /root/sniproxy/config.yaml
Restart=on-failure
RestartSec=3
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
UNIT_EOF
MUTATING=1
if (( WAS_ACTIVE )); then systemctl stop sniproxy.service; fi
install -m 755 "$TMP/sniproxy" "$INSTALL_DIR/sniproxy.new"
mv -f "$INSTALL_DIR/sniproxy.new" "$INSTALL_DIR/sniproxy"
if (( ! HAD_CONFIG )); then install -m 600 "$TMP/config.yaml" "$INSTALL_DIR/config.yaml";
else echo '[INFO] 保留服务器现有 config.yaml。'; fi
install -m 644 "$TMP/sniproxy.service" "$UNIT"
systemctl daemon-reload
systemctl enable sniproxy.service
systemctl restart sniproxy.service
sleep 4
if ! systemctl is-active --quiet sniproxy.service; then
  journalctl -u sniproxy.service -n 30 --no-pager >&2 || true
  fail '服务启动失败，退出后将尝试恢复。'
fi
MUTATING=0
echo "[OK] 已安装 SNIProxy v1.0.7。备份：$BACKUP"
echo '[INFO] 配置：/root/sniproxy/config.yaml'
echo '[INFO] 状态：systemctl status sniproxy --no-pager'
echo '[INFO] 日志：journalctl -u sniproxy -f'
echo '[INFO] 新安装监听 TCP 443；请在服务器防火墙中仅允许需要使用反代的客户端来源 IP。'
