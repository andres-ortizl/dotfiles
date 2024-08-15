from langchain_community.vectorstores.redis import Redis
from langchain_ollama import OllamaEmbeddings
from monodot.api.settings import get_settings
import redis


def redis_vector_store_client():
    settings = get_settings()
    return Redis(
        redis_url=settings.REDIS_CONNECTION_STRING.get_secret_value(),
        embedding=OllamaEmbeddings(model="llama3.1"),
        index_name=None,
    )


def redis_client():
    settings = get_settings()
    from loguru import logger

    logger.info(f"Connecting to Redis at {settings.REDIS_CONNECTION_STRING}")
    return redis.from_url(settings.REDIS_CONNECTION_STRING.get_secret_value())
