from openai import OpenAI

BASE_URL="http://localhost:8080/v1"
MODEL_NAME="Qwen3.6-35B-A3B-NVFP4"

def main():
    client = OpenAI(base_url=BASE_URL, api_key="dummy")

    response = client.chat.completions.create(
        model=MODEL_NAME,
        messages=[
        {"role": "user", "content": "こんにちは！"}
        ]
    )

    print(response.choices[0].message.content)

if __name__ == "__main__":
    main()