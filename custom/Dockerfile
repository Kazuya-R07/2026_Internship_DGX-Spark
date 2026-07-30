# ---------------------------
# ARG定義
# ---------------------------
# ビルドステージのベース: vLLMはprebuiltホイールをuvで入れるだけでCUDAツールチェインは不要なため、
# 軽量なUbuntuで十分(pull・apt処理が速くなる)
ARG BUILDER_IMAGE=ubuntu:22.04

# 実行ステージのベース: JITコンパイル(FlashInferなど、nvccが実行時に必要なモデル)を使わないなら
# -runtime で十分軽量。:
#   --build-arg IMAGE=nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04
ARG IMAGE=nvidia/cuda:13.0.3-cudnn-devel-ubuntu22.04

# uvのバージョン(latest固定でも動くが、再現性を重視するなら具体バージョンを指定)
ARG UV_VERSION=latest

# ---------------------------
# ビルドステージ
# ---------------------------
FROM ${BUILDER_IMAGE} AS builder

# uvバイナリを公式イメージから直接コピー(インストールスクリプト実行より高速・確実)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
ENV UV_LINK_MODE=copy

# HTTPS通信に必要な最小限のパッケージのみ
# (旧: build-essential等12パッケージ+Pythonソースビルドは、prebuiltバイナリ導入により不要に)
RUN --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates
# 注: apt系ディレクトリをcache mountにしている場合、rm -rf /var/lib/apt/lists/* は不要かつ逆効果。
#     cache mount配下は元々最終イメージ層に含まれないため、rmすると次回ビルド用キャッシュだけを消してしまう。

ENV UV_PYTHON_INSTALL_DIR=/opt/python
ARG PYTHON_VER=3.12.10

# uvでPython本体をインストール(ビルド不要のprebuiltバイナリなので数秒で完了。
# tar.xzの手動配置・configure/make等が丸ごと不要になる)
# python3 / python
# 見つかったインタプリタと同じディレクトリにシンボリックリンクを張っておく
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv python install ${PYTHON_VER} \
    && PYBIN="$(uv python find ${PYTHON_VER})" && PYDIR="$(dirname "${PYBIN}")" \
    && ln -sf "${PYBIN}" "${PYDIR}/python3" && ln -sf "${PYBIN}" "${PYDIR}/python" \
    && find "${PYDIR}/.." -maxdepth 3 -name EXTERNALLY-MANAGED -delete \
    && ln -sfn "${PYDIR}" /usr/local/pybin
ENV PATH="/usr/local/pybin:${PATH}"

ARG TORCH_VER=https://download.pytorch.org/whl/cu130
ARG VLLM_VER=0.21.0

# vLLMをuvでインストール(pipより大幅に高速)。
# --index-strategy unsafe-best-match は、--extra-index-url を跨いだバージョン解決の
# 取りこぼしを防ぐオプション。pip単体には存在せず、uv pip install経由でのみ有効な点に注意
# (以前 --index-strategy が認識されなかったのは、素のpipに対して指定していたためと考えられる)
RUN --mount=type=cache,target=/root/.cache/uv,sharing=locked \
    uv pip install --system --python python3 \
        vllm==${VLLM_VER} \
        --extra-index-url ${TORCH_VER} \
        --index-strategy unsafe-best-match

# ---------------------------
# メインステージ
# ---------------------------
FROM ${IMAGE} AS main

ARG UV_VERSION
ARG PYTHON_VER=3.12.10

# タイムゾーン設定
ENV TZ=Asia/Tokyo
RUN ln -sf /usr/share/zoneinfo/Asia/Tokyo /etc/localtime

# 実行に最低限必要なパッケージ
# (gitはモデル取得に必須ではない想定のため削除。git cloneでモデルを落とす運用があれば追加してください)
RUN --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=cache,target=/var/cache/apt,sharing=locked \
    sed -i 's|archive.ubuntu.com|jp.archive.ubuntu.com|g; s|http://security.ubuntu.com/ubuntu|http://jp.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        wget \
        curl

# uvバイナリと、Python+vLLM一式(/opt/python)をビルドステージからコピー
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/
ENV UV_LINK_MODE=copy
ENV UV_PYTHON_INSTALL_DIR=/opt/python
COPY --from=builder /opt/python /opt/python

ENV PATH="/usr/local/cuda/bin:${PATH}"
ENV MAX_JOBS=4
ENV CUTE_DSL_ARCH=sm_121a

# python3/python/pip3/pip へのシンボリックリンクを再構築(コピー先パスに合わせて張り直す)
RUN ln -sfn "$(dirname "$(uv python find ${PYTHON_VER})")" /usr/local/pybin
ENV PATH="/usr/local/pybin:${PATH}"

RUN uv pip install --system --python python3\
    "flashinfer-python==0.6.15.dev20260712" \
    "flashinfer-cubin==0.6.15.dev20260712" \
    "flashinfer-jit-cache==0.6.15.dev20260712" \
    --extra-index-url https://flashinfer.ai/whl/nightly/ \
    --extra-index-url https://flashinfer.ai/whl/nightly/cu130/ \
    --index-strategy unsafe-best-match

LABEL org.opencontainers.image.source="https://github.com/Kazuya-R07/2026_Internship_DGX-Spark.git"
LABEL org.opencontainers.image.description="vLLM runtime image for Laguna-S2.1"
LABEL org.opencontainers.image.licenses="Apache-2.0"