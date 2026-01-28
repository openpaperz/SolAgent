import json
import sys

from openai import OpenAI

from models.gpt5 import OPENAI_BASE_URL, OPENAI_API_KEY, gpt5_model, claude_model
from ms_agent import LLMAgent
from ms_agent.config import Config
import asyncio
import os

client = OpenAI(
    base_url=OPENAI_BASE_URL,
    api_key=OPENAI_API_KEY,
)

path = os.path.dirname(os.path.abspath(__file__))
dataset = os.path.join(path, 'data/dataset.json')
with open(dataset, "r", encoding="utf-8") as f:
    data = json.load(f)

code_agent_config = os.path.join(path, "coding.yaml")

async def chat():
    code_config = Config.from_task(code_agent_config)
    # code_config = gpt5_model(code_config)
    code_config = claude_model(code_config)

    # get a `.sol` file info to generate from dataset
    sol_path = None
    sol_content = None
    stop = False
    import_directive_stop = True # True to test with import directives.
    for file_path in data:
        if stop:
            break
        file_content = data[file_path]         # Get corresponding value (usually a list)
        if len(file_content) > 10:
            continue
        else:
            has_imports = any(
                bool(item.get("import_directive"))
                for item in file_content
            )
            if has_imports == import_directive_stop:
                stop = True
            else:
                continue

        sol_path = file_path
        sol_content = file_content

    sol_version = sol_content[0]["sol_version"][0]
    file_class = sol_content[0]["class"]
    file_name = sol_path.split("/")[-1]

    query = f"file name: {file_name}\n\n{sol_version}\nlibrary {file_class}\n"

    for method in sol_content:
        full_signature = method["full_signature"].strip()
        human_labeled_comment = method["human_labeled_comment"].strip()
        query = f"""{query}
{human_labeled_comment}
{full_signature}
"""
    print(query)

    del code_config.generation_config["stream"]
    del code_config.generation_config["top_p"]
    chat_completion = client.chat.completions.create(
        model=code_config.llm.model,
        messages=[{
                'role': 'user',
                'content': query
            }
        ],
        n=1,
        **code_config["generation_config"],
    )
    print(chat_completion.choices[0].message.role)
    print(chat_completion.choices[0].message.content)


if __name__ == '__main__':
    # Launch the async main function
    # asyncio.run(main())
    asyncio.run(chat())

