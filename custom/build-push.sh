#!/usr/bin/env bash
set -Eeuo pipefail

# Usage:
#   ./build-and-push.sh \
#     --repository ghcr.io/example-org/vllm \
#     --tag v0.21.0
#
# build.args を変更する場合:
#   ./build-and-push.sh \
#     -r ghcr.io/example-org/vllm \
#     -t v0.21.0 \
#     --args-file ./production.args \
#     --latest

DOCKERFILE="./Dockerfile"
CONTEXT="."
ARGS_FILE="./build.args"

REPOSITORY=""
TAG=""
PLATFORM=""
PUSH=true
TAG_LATEST=false

usage() {
  cat <<'EOF'
Usage:
  build-and-push.sh --repository REPOSITORY [options]

Required:
  -r, --repository REPOSITORY
      Push先イメージリポジトリ
      例: ghcr.io/example-org/vllm

Options:
  -t, --tag TAG
      イメージタグ。未指定時は Git の短縮コミットSHA、またはUTC日時を使用する。

  -a, --args-file FILE
      Docker build ARG 定義ファイル。
      default: ./build.args

  -f, --file FILE
      Dockerfile のパス。
      default: ./Dockerfile

  -c, --context DIR
      Docker build context。
      default: .

  -p, --platform PLATFORM
      ビルド対象プラットフォーム。
      例: linux/amd64

  -l, --latest
      latest タグも作成・pushする。

      --no-push
      pushせず、ローカルにイメージをロードする。

  -h, --help
      このヘルプを表示する。
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -r|--repository)
      REPOSITORY="${2:?--repository には値が必要です}"
      shift 2
      ;;
    -t|--tag)
      TAG="${2:?--tag には値が必要です}"
      shift 2
      ;;
    -a|--args-file)
      ARGS_FILE="${2:?--args-file には値が必要です}"
      shift 2
      ;;
    -f|--file)
      DOCKERFILE="${2:?--file には値が必要です}"
      shift 2
      ;;
    -c|--context)
      CONTEXT="${2:?--context には値が必要です}"
      shift 2
      ;;
    -p|--platform)
      PLATFORM="${2:?--platform には値が必要です}"
      shift 2
      ;;
    -l|--latest)
      TAG_LATEST=true
      shift
      ;;
    --no-push)
      PUSH=false
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: 不明なオプションです: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$REPOSITORY" ]]; then
  echo "ERROR: --repository は必須です。" >&2
  exit 1
fi

if [[ ! -f "$DOCKERFILE" ]]; then
  echo "ERROR: Dockerfile が見つかりません: $DOCKERFILE" >&2
  exit 1
fi

if [[ ! -f "$ARGS_FILE" ]]; then
  echo "ERROR: ARG 定義ファイルが見つかりません: $ARGS_FILE" >&2
  exit 1
fi

if [[ -z "$TAG" ]]; then
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    TAG="$(git rev-parse --short=12 HEAD)"
  else
    TAG="$(date -u +'%Y%m%d%H%M%S')"
  fi
fi

IMAGE="${REPOSITORY}:${TAG}"
LATEST_IMAGE="${REPOSITORY}:latest"

# Dockerfile の ARG に渡す値を build.args から読み込む。
# 空行および # から始まるコメント行は無視する。
BUILD_ARGS=()

while IFS= read -r line || [[ -n "$line" ]]; do
  # Windows の CRLF に対応
  line="${line%$'\r'}"

  # 空行・コメント行を無視
  [[ -z "$line" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # KEY=VALUE 形式であることを検証
  if [[ ! "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]]; then
    echo "ERROR: ARG 定義ファイルの形式が不正です: $line" >&2
    echo "       KEY=VALUE 形式で記述してください。" >&2
    exit 1
  fi

  BUILD_ARGS+=(--build-arg "$line")
done < "$ARGS_FILE"

export DOCKER_BUILDKIT=1

BUILD_CMD=(
  docker buildx build
  --file "$DOCKERFILE"
  --tag "$IMAGE"
)

if [[ -n "$PLATFORM" ]]; then
  BUILD_CMD+=(--platform "$PLATFORM")
fi

if [[ "$TAG_LATEST" == true ]]; then
  BUILD_CMD+=(--tag "$LATEST_IMAGE")
fi

if [[ "$PUSH" == true ]]; then
  # build 完了後に指定したタグをレジストリへ直接 push
  BUILD_CMD+=(--push)
else
  # ローカル Docker イメージストアへロード
  BUILD_CMD+=(--load)
fi

BUILD_CMD+=("${BUILD_ARGS[@]}")
BUILD_CMD+=("$CONTEXT")

echo "============================================================"
echo "Docker build settings"
echo "  Dockerfile : $DOCKERFILE"
echo "  Context    : $CONTEXT"
echo "  Args file  : $ARGS_FILE"
echo "  Image      : $IMAGE"
[[ "$TAG_LATEST" == true ]] && echo "  Latest     : $LATEST_IMAGE"
[[ -n "$PLATFORM" ]] && echo "  Platform   : $PLATFORM"
echo "  Push       : $PUSH"
echo "============================================================"

"${BUILD_CMD[@]}"

if [[ "$PUSH" == true ]]; then
  echo "Build and push completed."
  echo "Pushed image: $IMAGE"

  if [[ "$TAG_LATEST" == true ]]; then
    echo "Pushed image: $LATEST_IMAGE"
  fi
else
  echo "Build completed (push skipped)."
  echo "Local image: $IMAGE"
fi