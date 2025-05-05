import logging
import subprocess

from langchain.chat_models import init_chat_model
from langchain_core.messages import HumanMessage, SystemMessage
from typer import Typer

app = Typer()

logging.basicConfig(level=logging.WARNING)


def ask_llm(prompt: list, model: str = "gpt-4o-mini", temperature: float = 0) -> str:
    model = init_chat_model(model, model_provider="openai", temperature=temperature)
    r = model.invoke(prompt)
    return r.content


@app.command()
def slack(text: str):
    prompt = """
    You are an assistant that fixes spelling, grammar and punctuation.
    Don't insert any extra information; only provide the corrected text.
    After receiving corrections, the user can request clarifications,
    and you need to answer them in detail.
    The text could be in spanish but the output language should be always english.
    """
    messages = [
        SystemMessage(content=prompt),
        HumanMessage(content=text),
    ]
    response = ask_llm(messages)
    print(response)


@app.command()
def shit():
    prompt = """
    You are a highly skilled programmer with decades of experience.

    A junior programmer is learning under your guidance and frequently sends you code
    snippets of commands that failed to execute correctly.

    Your task is to carefully analyze each snippet and provide a clear, corrected version
    of the command in a single, straightforward response.

    For every successful fix you deliver, you will be rewarded with a $1000 bonus.
    """
    last_command = subprocess.run(
        "fc -ln -1",
        shell=True,
        capture_output=True,
        text=True,
        check=False,
    )
    print("hello")
    messages = [
        SystemMessage(content=prompt),
        HumanMessage(content=last_command.stdout.strip()),
    ]
    response = ask_llm(messages)
    print(response)


if __name__ == "__main__":
    app()
