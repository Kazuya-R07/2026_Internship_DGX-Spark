# 概要
これは2026年大塚商会インターンシップ用に用意された、DGX Sparkで動くローカルLLMのサンプルコンテナ環境です。

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
        参考: url(https://build.nvidia.com/spark/vllm/stacked-sparks)

# 使い方
## そのまま使う場合
## openweb uiと一緒に使う場合
## カスタムイメージをbuildして使う場合

# カスタマイズ
サンプルにない他のモデルを使う場合の手順と注意点
## `server.yaml(config.yaml)`について
どのようにカスタマイズするかなど

# よくあるエラーへの対処方法
