import asyncio
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sse_starlette import EventSourceResponse, ServerSentEvent  # <--- Clean SSE imports

app = FastAPI()

app.mount("/static", StaticFiles(directory="static"), name="static")

@app.get("/")
def serve_ui():
    return FileResponse("static/index.html")

class ChatRequest(BaseModel):
    prompt: str

@app.post("/chat/stream")
async def chat_stream(body: ChatRequest):
    # Define an async generator yielding structured ServerSentEvent objects
    async def event_generator():
        for i in range(1, 6):
            yield ServerSentEvent(
                event="number",
                data=f"Processed prompt '{body.prompt}' - Step {i}",
                id=str(i)
            )
            await asyncio.sleep(1)
        
        # Clean completion frame
        yield ServerSentEvent(
            event="done",
            data="Stream complete"
        )

    # Return an instance of EventSourceResponse wrapping the generator
    return EventSourceResponse(
        event_generator(),
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )