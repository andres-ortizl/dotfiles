import asyncio

from langchain_ollama import ChatOllama
from langchain_ollama import OllamaEmbeddings
import httpx
import polars as pl
from loguru import logger
import bs4
from pydantic import BaseModel

data_dir = "data/knowledge_base/data.csv"
MODEL = "llama3.1"


# @lru_cache(maxsize=1)
def ollama_client():
    return ChatOllama(
        model=MODEL,
        temperature=0,
    )


class Resource(BaseModel):
    url: str
    description_text: str | None = None


async def get_url_html(url: str) -> str:
    async with httpx.AsyncClient() as client:
        logger.info(f"Fetching {url}")
        response = await client.get(url)
        logger.info(f"Received {response.status_code} from {url}")
        response.raise_for_status()
        return response.text


def post_process_html(html: str) -> str:
    soup = bs4.BeautifulSoup(html, "html.parser")
    for script in soup(["script", "style"]):
        script.extract()

    text = soup.get_text()
    lines = (line.strip() for line in text.splitlines())
    chunks = (phrase.strip() for line in lines for phrase in line.split("  "))

    return "\n".join(chunk for chunk in chunks if chunk)


async def generate_description(url: str) -> Resource:
    try:
        logger.info(f"Generating description for {url}")
        html = await get_url_html(url)
        html = post_process_html(html)
        llm = ollama_client()
        messages = [
            (
                "system",
                "You are an expert at summarizing content. Your task is to provide a concise and clear summary of the main purpose and functionality "
                "of a tool or website, based on its description in the HTML content. Focus on explaining what the tool does, how it works, "
                "and the benefits of using it. Ignore references to any supplementary files or sections that do not directly describe the tool "
                "itself. Avoid including unnecessary details or technical jargon like installation instructions, focus on summaries. Assume that "
                "your are reding a tool website so that's not the tool itself.",
            ),
            ("human", html),
        ]
        description = await llm.ainvoke(messages)
        return Resource(url=url, description_text=description.content)
    except Exception as e:
        logger.error(f"Error processing {url}: {e}")
        return Resource(url=url)


async def generate_embedding(documents_text: list[str]) -> list[list[float]]:
    logger.info("Generating embeddings")
    llm = OllamaEmbeddings(model=MODEL)
    embeddings = await llm.aembed_documents(documents_text)
    return embeddings


async def process_data(batch_size: int = 5):
    df = pl.read_csv(data_dir)
    # filter out rows with empty url
    df = df.filter(df["url"].is_not_null())
    urls = df["url"].to_list()

    descriptions = []
    embeddings = []
    for i in range(0, len(urls), batch_size):
        batch_urls = urls[i : i + batch_size]
        batch_descriptions = await asyncio.gather(
            *(generate_description(url) for url in batch_urls)
        )
        descriptions.extend(batch_descriptions)
        embeddings.extend([desc.description_text for desc in batch_descriptions])
    df = df.with_columns(
        description_text=pl.Series(descriptions),
        description_embedding=pl.Series(await generate_embedding(embeddings)),
    )
    return df


async def main():
    df = await process_data()
    df.write_parquet("data/knowledge_base/data_with_description.parquet")


if __name__ == "__main__":
    asyncio.run(main())
