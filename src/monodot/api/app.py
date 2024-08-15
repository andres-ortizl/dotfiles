from fastapi import FastAPI, Request
from fastapi.templating import Jinja2Templates
from monodot.api.models import RequestResource, Resource
import uuid
from monodot.api.redis_api import redis_client

app = FastAPI()
templates = Jinja2Templates(directory="src/monodot/api/templates")


@app.get("/", include_in_schema=False)
def read_root(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})


@app.post("/")
async def add_resource(request: Request) -> Resource:
    form_data = await request.form()
    from loguru import logger

    logger.info(form_data)
    request = RequestResource.model_validate(form_data)
    resource = Resource(
        id=str(uuid.uuid4()),
        url=request.url,
        description_text=None,
        description_embedding=None,
    )
    redis = redis_client()
    redis.set(resource.id, resource.model_dump_json())
    return resource
