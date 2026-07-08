#!/bin/bash
set -euo pipefail

# ============================================================
# RAGFlow ARM64 镜像一键构建脚本（x86 宿主机执行）
# 优化点：前端使用 BUILDPLATFORM 原生架构编译，避免 QEMU 模拟
# ============================================================

# ========== 配置项 ==========
RAGFLOW_VERSION="${RAGFLOW_VERSION:-v0.26.3}"
DOCKER_USERNAME="${DOCKER_USERNAME:-your-username}"
IMAGE_TAG="${IMAGE_TAG:-${RAGFLOW_VERSION}-arm64}"
DEPS_IMAGE="${DEPS_IMAGE:-infiniflow/ragflow_deps:latest}"
BUILD_DEPS="${BUILD_DEPS:-false}"  # 是否需要自己构建 deps 镜像

echo "=========================================="
echo "  RAGFlow ARM64 镜像构建"
echo "  版本: ${RAGFLOW_VERSION}"
echo "  目标架构: linux/arm64"
echo "  前端优化: BUILDPLATFORM 原生编译"
echo "=========================================="

# ========== 环境检查 ==========
echo "[1/7] 检查 Docker 环境..."
if ! command -v docker &> /dev/null; then
    echo "❌ Docker 未安装，请先安装 Docker"
    exit 1
fi
echo "✅ Docker: $(docker --version)"

if ! docker buildx version &> /dev/null; then
    echo "❌ Docker BuildX 未安装"
    exit 1
fi
echo "✅ BuildX: $(docker buildx version)"

# ========== 配置 QEMU 跨架构支持 ==========
echo ""
echo "[2/7] 配置 QEMU 跨架构模拟..."
if ! docker run --privileged --rm tonistiigi/binfmt --install all 2>/dev/null; then
    echo "⚠️  QEMU 可能已配置，跳过"
else
    echo "✅ QEMU 已配置"
fi

# ========== 创建 BuildX 构建器 ==========
echo ""
echo "[3/7] 创建多架构 BuildX 构建器..."
BUILDER_NAME="ragflow-arm64-builder"
if ! docker buildx inspect "${BUILDER_NAME}" &> /dev/null; then
    docker buildx create --use --name "${BUILDER_NAME}" --driver docker-container
    echo "✅ 构建器 ${BUILDER_NAME} 已创建"
else
    docker buildx use "${BUILDER_NAME}"
    echo "✅ 使用已有构建器 ${BUILDER_NAME}"
fi

# ========== 获取源码 ==========
echo ""
echo "[4/7] 获取 RAGFlow 源码 (${RAGFLOW_VERSION})..."
WORK_DIR="$(cd "$(dirname "$0")" && pwd)"
RAGFLOW_DIR="${WORK_DIR}/ragflow-src"

if [ -d "${RAGFLOW_DIR}" ]; then
    echo "⚠️  源码目录已存在，更新中..."
    cd "${RAGFLOW_DIR}"
    git fetch --tags
    git checkout "${RAGFLOW_VERSION}"
else
    git clone --depth 1 --branch "${RAGFLOW_VERSION}" https://github.com/infiniflow/ragflow.git "${RAGFLOW_DIR}"
fi
echo "✅ 源码准备完成"

# ========== 替换优化后的 Dockerfile ==========
echo ""
echo "[5/7] 替换为 ARM64 优化 Dockerfile..."
cp "${WORK_DIR}/Dockerfile.arm64-optimized" "${RAGFLOW_DIR}/Dockerfile"

# 修改 Dockerfile 中的 deps 镜像引用
if [ "${DEPS_IMAGE}" != "infiniflow/ragflow_deps:latest" ]; then
    sed -i "s|infiniflow/ragflow_deps:latest|${DEPS_IMAGE}|g" "${RAGFLOW_DIR}/Dockerfile"
    echo "✅ DEPS 镜像已替换为: ${DEPS_IMAGE}"
fi
echo "✅ Dockerfile 已优化"

# ========== 构建 DEPS 镜像（可选） ==========
if [ "${BUILD_DEPS}" = "true" ]; then
    echo ""
    echo "[6/7] 构建 ragflow_deps 基础依赖镜像 (ARM64)..."
    cd "${RAGFLOW_DIR}"
    
    # 安装 Python 依赖并下载
    pip install huggingface_hub tqdm
    python3 download_deps.py
    
    docker buildx build \
        --platform linux/arm64 \
        -f Dockerfile.deps \
        -t "${DOCKER_USERNAME}/ragflow_deps:${IMAGE_TAG}" \
        --push \
        .
    echo "✅ ragflow_deps 镜像已推送: ${DOCKER_USERNAME}/ragflow_deps:${IMAGE_TAG}"
fi

# ========== 构建主镜像 ==========
echo ""
echo "[7/7] 构建 RAGFlow 主镜像 (ARM64 + 原生前端编译)..."
cd "${RAGFLOW_DIR}"

docker buildx build \
    --platform linux/arm64 \
    -f Dockerfile \
    -t "${DOCKER_USERNAME}/ragflow:${IMAGE_TAG}" \
    --push \
    .

echo ""
echo "=========================================="
echo "  🎉 构建完成！"
echo "  镜像: ${DOCKER_USERNAME}/ragflow:${IMAGE_TAG}"
echo "  架构: linux/arm64"
echo "=========================================="
echo ""
echo "ARM 机器部署方法："
echo "1. 进入 ragflow/docker 目录"
echo "2. 修改 .env 中 RAGFLOW_IMAGE=${DOCKER_USERNAME}/ragflow:${IMAGE_TAG}"
echo "3. 执行 docker compose up -d"
