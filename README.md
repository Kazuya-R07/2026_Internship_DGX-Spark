# 概要
これは2026年大塚商会インターンシップ用に用意された、DGX Sparkで動くローカルLLMのサンプルコンテナ環境です。

OpenAI互換APIサーバ(`/v1`)をコンテナで立ち上げ、Open WebUIやPythonクライアントから利用できます。

# Model
- Qwen3.6-35B-A3B: nvidia/Qwen3.6-35B-A3B-NVFP4
    - Thinking
    - Middle class flontier
    - Alibaba, China
    - Nvidia quantized
    - Dflash and MTP Layer
    - url(https://huggingface.co/nvidia/Qwen3.6-35B-A3B-NVFP4)

- DiffusionGemma: google/diffusiongemma-26B-A4B-it-NVFP4
    - Thinking
    - Fastest
    - Diffusion LLM
    - Google, US.
    - Nvidia quantized
    - url(https://huggingface.co/nvidia/diffusiongemma-26B-A4B-it-NVFP4)

- Laguna-S-2.1: poolside/Laguna-S-2.1-NVFP4
    - Thinking
    - Highest Inteligence working in DGX Spark
    - Poolside, US.
    - Poolside quantized
    - Dflash Layer
    - 118B-A8B
    - url(https://huggingface.co/poolside/Laguna-S-2.1-NVFP4)

# Inference Engine
- vllm:
    - 最もメジャーな推論エンジン
    - 並列推論が得意で、開発スピードもNo1。最も多くのモデルに対応している
    - url(https://github.com/vllm-project/vllm)
- Atlas:
    - DGX Sparkに最適化された**Rust**製の推論エンジン
    - Qwen, Gemma, MiniMax等に対応
    - url(https://github.com/Avarok-Cybersecurity/atlas/tree/main)

# 使用イメージ
- Diffusiongemma: vllm/vllm-openai:gemma
    - vllmがカスタムしたイメージ
- Laguna: ghcr.io/kazuya-r07/laguna-s-2-1:latest
    - 自己カスタムイメージ(`/custom`にあるDockerfileを使用)
    - 参考: url(https://huggingface.co/poolside/Laguna-S-2.1-NVFP4)
- Qwen3.6-35B-atlas: avarok/atlas-gb10:latest
    - atlas開発者が提供しているイメージ
- Qwen3.6-35B-vllm: nvcr.io/nvidia/vllm:26.06-py3
    - Nvidiaが提供しているDGX Spark向けのvllmイメージ
    - 参考: url(https://build.nvidia.com/spark/vllm/stacked-sparks)

# ディレクトリ構成
```
.
├── docker-compose.yaml     # Open WebUI + 各モデルのcomposeをincludeする親compose
├── .env                    # 親compose用の環境変数(Open WebUIのポート、接続先など)
├── Qwen3.6-35B-vllm/       # Qwen3.6をvLLM(Nvidia製イメージ)で起動
├── Qwen3.6-35B-atlas/      # Qwen3.6をAtlasで起動(Dockerfileなし。公式イメージをそのまま使用)
├── Diffusiongemma/         # DiffusionGemmaをvLLM(vllm製gemmaイメージ)で起動
├── Laguna/                 # Laguna-S-2.1をvLLM(自己ビルドイメージ)で起動
├── custom/                 # 自己カスタムイメージのDockerfileとbuild/pushスクリプト
└── client/                 # OpenAI SDKでAPIを叩くサンプルクライアント(uvプロジェクト)
```

各モデルディレクトリの中身は共通で、以下の3〜4ファイルです。

| ファイル | 役割 |
| --- | --- |
| `docker-compose.yaml` | GPU割り当て・ポート・モデルウェイトのbind mount・healthcheckの定義 |
| `.env` | 使用イメージ、モデル名、ウェイトのホストパス、ポートなどの設定値 |
| `Dockerfile` | ベースイメージに`server.yaml`をCOPYし、`vllm serve`をENTRYPOINTにするだけの薄いラッパー |
| `server.yaml` | vLLMの起動オプション(`vllm serve --config`に渡す設定ファイル) |

> Atlasは起動オプションを`server.yaml`ではなく`docker-compose.yaml`の`command`に直接書いているため、
> `Dockerfile`と`server.yaml`がありません。

# 事前準備
## 1. 動作環境の確認
- DGX Spark (GB10 / `sm_121a`)
- Docker および NVIDIA Container Toolkit がセットアップ済みであること

```bash
# GPUが見えているか確認
nvidia-smi

# コンテナからGPUが見えるか確認
docker run --rm --gpus all nvcr.io/nvidia/cuda:13.0.3-base-ubuntu22.04 nvidia-smi
```

## 2. モデルウェイトのダウンロード
ウェイトはリポジトリに含まれていません(`.gitignore`で`*.safetensors`を除外)。
使用するモデルをHugging Faceから任意のディレクトリへダウンロードしておきます。

```bash
uv tool install "huggingface_hub[cli]"

hf download nvidia/Qwen3.6-35B-A3B-NVFP4 \
  --local-dir /home/internship_dgx2/temp_download/Qwen3.6-35B-A3B-NVFP4
```

ダウンロード先ディレクトリの直下に`config.json`が存在することを必ず確認してください。
コンテナはこのディレクトリをそのままモデルパスとしてマウントします。

## 3. `.env`の設定
各モデルディレクトリの`.env`を自分の環境に合わせて書き換えます(`Qwen3.6-35B-vllm/.env.example`を参照)。

| 変数 | 説明 | 例 |
| --- | --- | --- |
| `IMAGE` | ベースとなるコンテナイメージ名 | `nvcr.io/nvidia/vllm:26.06-py3` |
| `RAM_SIZE` | コンテナの共有メモリサイズ(`shm_size`) | `48g` |
| `MODEL_NAME` | **モデルウェイト(config.json)が含まれる親ディレクトリの名前** | `Qwen3.6-35B-A3B-NVFP4` |
| `HOST_MODELPATH` | ホスト側のウェイト格納ディレクトリの絶対パス | `/home/.../Qwen3.6-35B-A3B-NVFP4` |
| `API_PORT` | ホスト側に公開する`/v1`エンドポイントのポート | `8080` |
| `TORCH_CUDA_ARCH_LIST` | GPUアーキテクチャの型番。GB10は`sm_121a` | `"12.1"` |

`HOST_MODELPATH`はコンテナ内の`/root/.cache/huggingface/hub/${MODEL_NAME}`にマウントされ、
そのパスがそのまま`vllm serve`の引数になります。したがって
**`MODEL_NAME`は`HOST_MODELPATH`の末尾ディレクトリ名と一致させてください。**

# 使い方
## そのまま使う場合
使いたいモデルのディレクトリに移動して`docker compose up`するだけです。

```bash
cd Qwen3.6-35B-vllm
docker compose up --build      # 初回はイメージのpull/buildが走る
```

- 初回はイメージのダウンロードとモデルのロードで時間がかかります。
  ログに`Application startup complete`(vLLM)が出れば起動完了です。
- healthcheckが`/v1/models`を叩いているため、`docker compose ps`のSTATUSが`healthy`になったかでも判断できます。

動作確認:

```bash
# モデル一覧(served_model_name が返ってくる)
curl http://localhost:8080/v1/models

# チャット補完
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "Qwen3.6-35B-A3B-NVFP4",
    "messages": [{"role": "user", "content": "こんにちは！"}]
  }'
```

停止・後片付け:

```bash
docker compose down            # コンテナを停止・削除
docker compose logs -f         # ログ追従(起動が進まないときの調査用)
```

Pythonから叩く場合は`client/`のサンプルを使います。APIキーは不要ですが、
OpenAI SDKが要求するのでダミー文字列を渡します。

```bash
cd client
uv sync
uv run python -m client.openai_client
```

接続先やモデル名は`client/src/client/openai_client.py`冒頭の`BASE_URL` / `MODEL_NAME`で変更できます。
`MODEL_NAME`には`server.yaml`の`served_model_name`の値を指定してください。

## openweb uiと一緒に使う場合
リポジトリ直下の`docker-compose.yaml`が、モデルのcomposeを`include`しつつOpen WebUIを起動します。

1. 直下の`docker-compose.yaml`で、使いたいモデルの行だけコメントアウトを外します。

```yaml
include:
  # - Diffusiongemma/docker-compose.yaml
  # - Laguna/docker-compose.yaml
  - Qwen3.6-35B-vllm/docker-compose.yaml
  # - Qwen3.6-35B-atlas/docker-compose.yaml
```

2. 直下の`.env`を確認します。

| 変数 | 説明 | 既定値 |
| --- | --- | --- |
| `OPENAI_API_BASE_URL` | Open WebUIからモデルへの接続先(コンテナ間通信) | `http://serve_vllm:8000/v1` |
| `MODEL_NAME` | Open WebUIの既定モデル。`server.yaml`の`served_model_name`と一致させる | `Qwen3.6-35B-A3B-NVFP4` |
| `PORT` | Open WebUIをホストに公開するポート | `3030` |

3. 起動してブラウザで`http://localhost:3030`(=`${PORT}`)を開きます。

```bash
docker compose up --build
```

Open WebUIはモデルコンテナが`healthy`になるまで起動を待つ(`depends_on: service_healthy`)ため、
初回はモデルのロード完了まで画面が開きません。`ENABLE_SIGNUP: "False"`のため、
初回に作成した管理者アカウント以降のサインアップは無効になっています。

> **注意(Atlasを選んだ場合)**
> 親composeの`depends_on`は`serve_vllm`を指しています。Atlas側のサービス名は`serve_atlas`なので、
> `Qwen3.6-35B-atlas/docker-compose.yaml`をincludeするときは親composeの`depends_on`と
> `.env`の`OPENAI_API_BASE_URL`(`http://serve_atlas:8888/v1`)も併せて書き換えてください。

## カスタムイメージをbuildして使う場合
公開イメージに使いたいモデルのサポートが入っていない場合、`custom/`のDockerfileから
vLLM入りのイメージを自前でビルドします(Lagunaはこの方法でビルドしたイメージを使用しています)。

`custom/Dockerfile`はマルチステージ構成です。

- **builderステージ**: 軽量な`ubuntu:22.04`上で`uv`を使いPython本体とvLLMのprebuiltホイールを導入
- **mainステージ**: CUDAイメージ上にbuilderの`/opt/python`をコピーし、FlashInferを追加インストール

バージョンは`custom/build.args`で指定します。

```
TORCH_VER=https://download.pytorch.org/whl/cu130
VLLM_VER=0.25.1
```

ビルドとpushは`custom/build-push.sh`で行います。

```bash
cd custom

# ローカルにビルドするだけ(pushしない)
./build-push.sh -r ghcr.io/<your-org>/laguna-s-2-1 -t dev --no-push

# レジストリへpush(latestタグも付ける)
./build-push.sh -r ghcr.io/<your-org>/laguna-s-2-1 -t v0.25.1 --latest
```

主なオプション(`./build-push.sh --help`で一覧表示):

| オプション | 説明 |
| --- | --- |
| `-r, --repository` | **必須**。push先イメージリポジトリ |
| `-t, --tag` | イメージタグ。未指定時はGitの短縮コミットSHA(なければUTC日時) |
| `-a, --args-file` | build ARG定義ファイル(default: `./build.args`) |
| `-l, --latest` | `latest`タグも作成・pushする |
| `--no-push` | pushせずローカルのイメージストアへロードする |

pushする場合は事前にレジストリへログインしておきます。

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u <username> --password-stdin
```

ビルドしたイメージは、使いたいモデルディレクトリの`.env`の`IMAGE`に指定すれば利用できます。

```
IMAGE=ghcr.io/<your-org>/laguna-s-2-1:latest
```

# カスタマイズ
サンプルにない他のモデルを使う場合の手順と注意点

## 新しいモデルを追加する手順
1. 既存のモデルディレクトリ(例: `Qwen3.6-35B-vllm/`)を丸ごとコピーして、新しい名前にします。
2. ウェイトをダウンロードし、`.env`の`MODEL_NAME` / `HOST_MODELPATH` / `RAM_SIZE`を書き換えます。
3. `server.yaml`をモデルに合わせて調整します(下記参照)。特に`served_model_name`、
   `reasoning-parser`、`tool-call-parser`はモデル固有です。
4. 単体で`docker compose up --build`し、`curl http://localhost:${API_PORT}/v1/models`で応答を確認します。
5. Open WebUIと併用する場合は、直下の`docker-compose.yaml`の`include`に追加し、
   直下の`.env`の`MODEL_NAME`を`served_model_name`に合わせます。

## 注意点
- **量子化形式とイメージの対応**: NVFP4はBlackwell(GB10)世代前提の形式です。対応していない
  vLLMバージョンのイメージでは起動しません。モデルカード記載の推奨バージョン以上のイメージを選ぶか、
  `custom/`で自前ビルドしてください。
- **パーサの有無**: `reasoning-parser` / `tool-call-parser`に指定できる名前は、vLLMが実装済みの
  ものに限られます。未対応の名前を書くと起動時にエラーになります。不明な場合はまず両方を外して
  起動し、動作を確認してから足すのが安全です。
- **メモリ**: DGX Sparkはユニファイドメモリのため、`gpu-memory-utilization`を上げすぎると
  ホスト側が枯渇します。まず`0.80`前後から始めてください。
- **`shm_size`**: モデルサイズに応じて`.env`の`RAM_SIZE`を調整します
  (サンプルでは35B→`48g`、118B→`80g`、26B→`16g`)。

## `server.yaml(config.yaml)`について
`server.yaml`は`vllm serve <model> --config /server.yaml`に渡される設定ファイルで、
CLIオプション名からハイフン2つ(`--`)を除いたものがそのままキーになります
(例: `--max-model-len 128000` → `max-model-len: 128000`)。
JSONを取る引数は、シングルクォートで囲んだ文字列として書きます。

サンプル(`Qwen3.6-35B-vllm/server.yaml`)の主要な項目:

| キー | 説明 |
| --- | --- |
| `port` | コンテナ内でlistenするポート。compose側の`ports`と対応させる(vLLMは`8000`) |
| `served_model_name` | APIが公開するモデル名。**クライアントやOpen WebUIはこの名前を指定する** |
| `max-model-len` | 最大コンテキスト長。長くするほどKVキャッシュを消費する |
| `gpu-memory-utilization` | GPUメモリの使用率上限。OOM時はまずここを下げる |
| `max-num-seqs` | 同時処理シーケンス数。並列数を増やすとメモリも増える |
| `max_num_batched_tokens` | 1バッチあたりの最大トークン数 |
| `reasoning-parser` | Thinking出力を`reasoning_content`として分離するパーサ(モデル固有) |
| `tool-call-parser` / `enable-auto-tool-choice` | Function callingの出力を解釈するパーサ(モデル固有) |
| `enable-prefix-caching` | 共通プレフィックスのKVキャッシュを再利用し、多ターン会話を高速化 |
| `enable-chunked-prefill` | 長いプロンプトのprefillを分割し、レイテンシを平準化 |
| `speculative-config` | 投機的デコード(DFlash/MTP)の設定。ドラフトモデルのウェイトも別途必要 |
| `override-generation-config` | temperature等の既定サンプリングパラメータの上書き |
| `quantization` | 量子化バックエンド。NVFP4(ModelOpt製)は`modelopt` |

`# changeable`とコメントされている行は、環境や用途に応じて調整してよい項目です。

チューニングの目安:

- **メモリが足りない**: `gpu-memory-utilization`↓ → `max-model-len`↓ → `max-num-seqs`↓ の順で下げる
- **スループットを上げたい**: `max-num-seqs`↑、`max_num_batched_tokens`↑、`enable-prefix-caching`を有効化
- **レイテンシを下げたい**: `speculative-config`(投機的デコード)を有効化、`stream-interval`を調整
- **まず起動を通したい**: `speculative-config`、`quantization`、各種parserを一旦コメントアウトして最小構成で試す

Atlasの場合は`server.yaml`ではなく`docker-compose.yaml`の`command`配列にCLIオプションを直接記述します
(`--max-seq-len`、`--gpu-memory-utilization`、`--kv-cache-dtype`など。オプション名がvLLMと異なる点に注意)。

# よくあるエラーへの対処方法

## `could not select device driver "nvidia" with capabilities: [[gpu]]`
NVIDIA Container ToolkitがDockerに登録されていません。

```bash
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
docker run --rm --gpus all nvcr.io/nvidia/cuda:13.0.3-base-ubuntu22.04 nvidia-smi
```

## `OSError: ... does not appear to have a file named config.json`
`MODEL_NAME`と`HOST_MODELPATH`の対応が取れていません。
`HOST_MODELPATH`直下に`config.json`があるか、`MODEL_NAME`が`HOST_MODELPATH`の末尾ディレクトリ名と
一致しているかを確認してください。

```bash
ls ${HOST_MODELPATH}/config.json
```

## 起動途中でOOM / `CUDA out of memory`
`server.yaml`の`gpu-memory-utilization`を下げます(例: `0.85` → `0.75`)。
それでも収まらない場合は`max-model-len`、`max-num-seqs`の順に下げてください。
`speculative-config`はドラフトモデルの分だけ追加でメモリを使うため、切り分けのため一時的に
コメントアウトするのも有効です。

## コンテナが起動直後に落ちる / 共有メモリ不足
`.env`の`RAM_SIZE`(=`shm_size`)を増やします。モデルサイズに対して小さすぎると
ロード中にプロセスが落ちます。

## `bind: address already in use`
`API_PORT`(既定`8080`)や`PORT`(既定`3030`)が他のプロセスと衝突しています。
`.env`の値を変更するか、使用中のプロセスを止めてください。

```bash
ss -ltnp | grep -E '8080|3030'
```

## STATUSがずっと`starting` / `unhealthy`のまま
- モデルのロードには数分かかります。まず`docker compose logs -f`で進行状況を確認してください。
- healthcheckは`retries: 60`、`interval: 10s`のため、約10分応答がないと`unhealthy`になります。
- Atlas(`Qwen3.6-35B-atlas`)のhealthcheckは`localhost:8000`を見ていますが、Atlasは`8888`で
  listenしています。Atlasを使う場合はhealthcheckの宛先を`8888`に修正してください。

## Open WebUIにモデルが表示されない
- 直下の`.env`の`MODEL_NAME`が、`server.yaml`の`served_model_name`と一致しているか確認します
  (**ウェイトのディレクトリ名ではありません**)。DiffusionGemmaの場合、ディレクトリ名は
  `diffusiongemma-26B-A4B-it-NVFP4`ですが`served_model_name`は`DiffusionGemma-NVFP4`です。
- `OPENAI_API_BASE_URL`はコンテナ間通信のため`localhost`ではなくサービス名
  (`http://serve_vllm:8000/v1`)を指定します。ポートもホスト側の`API_PORT`ではなく
  コンテナ内のポート(vLLM: `8000`、Atlas: `8888`)です。

## `ValueError: Unknown reasoning parser` / `tool call parser`
そのvLLMバージョンに存在しないパーサ名を指定しています。イメージのバージョンを上げるか、
該当行をコメントアウトして起動してください。

## イメージのpull / ビルドが進まない(社内ネットワーク)
プロキシ配下では、Dockerデーモンとビルド時の双方にプロキシ設定が必要です。
`~/.docker/config.json`や`/etc/systemd/system/docker.service.d/http-proxy.conf`に設定してください。
なお`.env`にプロキシ設定を書くとイメージや環境に紐づいてしまうため、共有リポジトリへは
コミットしないよう注意してください。

## `nvcr.io`のイメージがpullできない
NGCへのログインが必要な場合があります。

```bash
docker login nvcr.io   # Username: $oauthtoken / Password: <NGC API Key>
```

## 切り分けのための基本コマンド
```bash
docker compose ps                       # STATUS(healthy/unhealthy)の確認
docker compose logs -f serve_vllm       # 推論サーバのログ
docker stats                            # メモリ使用量の確認
nvidia-smi                              # GPU使用状況の確認
curl -f http://localhost:8080/v1/models # APIの疎通確認
```
