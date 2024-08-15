import uvicorn
from monodot.api.settings import get_settings

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "app:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level=settings.LOG_LEVEL,
        reload=settings.RELOAD,
    )
