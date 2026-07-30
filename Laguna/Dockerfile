ARG IMAGE=nvcr.io/nvidia/vllm:26.07-py3

FROM ${IMAGE}

COPY server.yaml /server.yaml

ENTRYPOINT ["sh", "-c", "vllm serve /root/.cache/huggingface/hub/${MODEL_NAME} --config /server.yaml"]