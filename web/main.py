import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from sse_starlette import EventSourceResponse, ServerSentEvent  # <--- Clean SSE imports
from ollama import AsyncClient

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.ollama = AsyncClient(host="http://local-container-ollama:11434")
    try:
        yield
    finally:
        # Clean up underlying HTTP client if present
        client = app.state.ollama
        if hasattr(client, "_client") and hasattr(client._client, "aclose"):
            await client._client.aclose()

app = FastAPI(lifespan=lifespan)

app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/")
def serve_ui():
    return FileResponse("static/index.html")

class ChatRequest(BaseModel):
    prompt: str

@app.post("/chat/stream")
async def chat_stream(body: ChatRequest, request: Request):    
    client = request.app.state.ollama
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

    async def ollama_event():
        stream = await client.chat(
            model="llama3.2",
            messages=[{"role": "user", "content": body.prompt}],
            stream=True,
        )

        batch_size = 10
        buffer = ""

        async for chunk in stream:
            content = chunk.message.content if chunk.message else ""
            if not content:
                continue

            buffer += content
            words = buffer.split()

            if len(words) >= batch_size:
                emit_text = " ".join(words[:batch_size])
                # Preserve any trailing text after the 10th word (including trailing whitespace/newlines)
                remainder_start = buffer.find(words[batch_size - 1])
                after_tenth = buffer[remainder_start + len(words[batch_size - 1]) :].lstrip(" ")

                yield ServerSentEvent(
                    event="message",
                    data=emit_text,
                )
                buffer = after_tenth

        # Flush any remaining words (< 10) when the model finishes
        if buffer.strip():
            yield ServerSentEvent(
                event="message",
                data=buffer.strip(),
            )

        yield ServerSentEvent(
            event="done",
            data="Stream complete",
        )

    # Return an instance of EventSourceResponse wrapping the generator
    return EventSourceResponse(
        ollama_event(),
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )