#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="sniproxy"
INSTALL_DIR="/root/sniproxy"
BIN_PATH="${INSTALL_DIR}/sniproxy"
CONFIG_FILE="${INSTALL_DIR}/config.yaml"
LOG_FILE="${INSTALL_DIR}/sniproxy.log"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

GITHUB_USER="zbklk"
GITHUB_REPO="sni_proxy"
GITHUB_BRANCH="main"

CONFIG_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${GITHUB_BRANCH}/config.yaml"

VERSION="v1.0.6"

echo "[INFO] 开始 SNIProxy 安装和配置..."

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] 请使用 root 运行此脚本。"
    exit 1
fi

echo "[INFO] Root 权限检查通过。"

echo "[INFO] 检查依赖项 (curl, tar, systemctl, dpkg)..."
for cmd in curl tar systemctl dpkg; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "[ERROR] 缺少依赖: $cmd"
        exit 1
    fi
done
echo "[INFO] 依赖检查通过。"

echo "[INFO] 创建工作目录 ${INSTALL_DIR}..."
mkdir -p "${INSTALL_DIR}"

ARCH="$(dpkg --print-architecture)"
case "$ARCH" in
    amd64)
        FILE_ARCH="amd64"
        ;;
    arm64)
        FILE_ARCH="arm64"
        ;;
    *)
        echo "[ERROR] 不支持的系统架构: ${ARCH}"
        exit 1
        ;;
esac

echo "[INFO] 检测到系统架构: ${ARCH}"

DOWNLOAD_URL="https://github.com/XIU2/SNIProxy/releases/download/${VERSION}/sniproxy_linux_${FILE_ARCH}.tar.gz"
TMP_FILE="/tmp/sniproxy_linux_${FILE_ARCH}.tar.gz"
TMP_EXTRACT_DIR="/tmp/sniproxy_extract_$$"

if systemctl list-unit-files | grep -q "^${SERVICE_NAME}.service"; then
    echo "[INFO] 检测到已存在的 ${SERVICE_NAME} 服务，正在停止..."
    systemctl stop "${SERVICE_NAME}" || true
fi

echo "[INFO] 正在下载 SNIProxy ${VERSION}..."
curl -fsSL --connect-timeout 10 --max-time 120 "${DOWNLOAD_URL}" -o "${TMP_FILE}"

if [ ! -s "${TMP_FILE}" ]; then
    echo "[ERROR] 下载失败，文件为空。"
    exit 1
fi

echo "[INFO] 下载完成，开始解压..."
rm -rf "${TMP_EXTRACT_DIR}"
mkdir -p "${TMP_EXTRACT_DIR}"
tar -xzf "${TMP_FILE}" -C "${TMP_EXTRACT_DIR}"

if [ ! -f "${TMP_EXTRACT_DIR}/sniproxy" ]; then
    echo "[ERROR] 解压后未找到 sniproxy 可执行文件。"
    exit 1
fi

echo "[INFO] 安装 sniproxy 到 ${BIN_PATH}..."
cp "${TMP_EXTRACT_DIR}/sniproxy" "${BIN_PATH}"
chmod +x "${BIN_PATH}"

echo "[INFO] 清理临时文件..."
rm -f "${TMP_FILE}"
rm -rf "${TMP_EXTRACT_DIR}"

echo "[INFO] 正在从 GitHub 拉取配置文件..."
curl -fsSL --connect-timeout 10 --max-time 30 "${CONFIG_URL}" -o "${CONFIG_FILE}"

if [ ! -s "${CONFIG_FILE}" ]; then
    echo "[ERROR] 配置文件下载失败或为空: ${CONFIG_URL}"
    exit 1
fi

echo "[INFO] 配置文件写入成功：${CONFIG_FILE}"

echo "[INFO] 创建 systemd 服务文件..."
cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=SNI Proxy
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${BIN_PATH} -c ${CONFIG_FILE} -l ${LOG_FILE}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "[INFO] 重新加载 systemd 配置..."
systemctl daemon-reload

echo "[INFO] 设置开机自启..."
systemctl enable "${SERVICE_NAME}"

echo "[INFO] 启动服务..."
systemctl restart "${SERVICE_NAME}"

echo "[INFO] 检查服务状态..."
systemctl --no-pager --full status "${SERVICE_NAME}"

echo
echo "[INFO] 安装完成。"
echo "[INFO] 配置文件: ${CONFIG_FILE}"
echo "[INFO] 日志文件: ${LOG_FILE}"
echo "[INFO] 查看实时日志命令: journalctl -u ${SERVICE_NAME} -f"
