from pydantic import BaseModel


class RequestResource(BaseModel):
    url: str
    name: str


class Resource(BaseModel):
    id: str
    url: str
    description_text: str | None
    description_embedding: float | None
