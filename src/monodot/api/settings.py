from pydantic import BaseModel
from starlette.config import Config
from pydantic import SecretStr

config = Config()


class Settings(BaseModel):
    HOST: str = config("HOST", default="localhost", cast=str)
    PORT: int = config("PORT", default=8080, cast=int)
    LOG_LEVEL: str = config("LOG_LEVEL", default="info")
    RELOAD: bool = config("RELOAD", default=True, cast=bool)
    REDIS_CONNECTION_STRING: SecretStr = config(
        "REDIS_CONNECTION_STRING", default="", cast=SecretStr
    )


def get_settings() -> Settings:
    return Settings()
