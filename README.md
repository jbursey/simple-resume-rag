# simple_rag
100% local, privacy-focused RAG system that ingests resumes, parses them into semantic chunks, and indexes them in a local Qdrant vector database via Ollama embeddings. It evaluates candidate-to-job fits using a local LLM and strict Pydantic JSON enforcement.


# Project Roadmap & User Stories: Local RAG & Memory Chat System

This blueprint outlines the iterative phases, user stories, and technical acceptance criteria for building your local LLM, Memory, and Resume RAG system. Designed to be executed step-by-step so you maintain full architectural control.

---

## Phase 1: Local Infrastructure & Orchestration
**Goal:** Establish a self-contained, multi-container local development environment using `wslc` with isolated networking and persistent storage.

### User Stories & Tasks
- [ ] **Network Setup:** Create a dedicated bridge network (`local-llm-net`) so all containers can resolve each other by container name (e.g., `http://ollama:11434`, `http://qdrant:6333`, `mysql:3306`).
- [ ] **Ollama Container:** Provision a `wslc` container running Ollama attached to `local-llm-net` with persistent volume storage for downloaded model weights (`nomic-embed-text` and your chosen chat/reasoning model).
- [ ] **MySQL Container (Memory Store):** Provision a `wslc` container running MySQL attached to `local-llm-net`, initialized with a persistent volume, root/user credentials, and a target database (e.g., `llm_memory`).
- [ ] **Qdrant Container (Vector DB):** Provision a `wslc` container running `qdrant/qdrant` attached to `local-llm-net`, exposing ports `6333`/`6334` and mounting a local volume (`./qdrant_data`) for vector persistence.
- [ ] **Python Web API Container:** Provision a `wslc` container for the FastAPI backend attached to `local-llm-net`, configured with a local bind-mount (`./app:/app`) so code edits reflect immediately without rebuilding images.
- [ ] **Lifecycle Orchestration Script:** Write a shell script (`manage.sh` or `stack.ps1`) supporting `./manage.sh up` and `./manage.sh down` to cleanly create/start or stop/remove the network and containers in the proper dependency order.
- [ ] **Health & Connectivity Verification:** Verify that the Python container can successfully ping/reach Ollama, MySQL, and Qdrant over `local-llm-net`, and that required Ollama models are pulled and ready.

---

## Phase 2: "Hello LLM World" (Streaming UI & Proxy)
**Goal:** Build a minimal, responsive web interface that streams real-time token responses from Ollama through your FastAPI backend.

### User Stories & Tasks
- [ ] **FastAPI Streaming Endpoint:** Create a `POST` or `GET` endpoint (e.g., `/chat/stream`) in FastAPI that accepts a user prompt, forwards it to Ollama's `/api/generate` or `/api/chat` endpoint with `stream=True`, and yields chunks via `StreamingResponse` (`text/event-stream`).
- [ ] **CORS & Static Serving:** Configure FastAPI to serve `index.html` directly (or enable CORS) so local browser requests connect cleanly without cross-origin blocks.
- [ ] **Split-Pane Web UI (`index.html`):** Build a single-page HTML/CSS layout featuring a prompt input pane on the left and a response display pane on the right.
- [ ] **SSE Client Integration:** Write vanilla JavaScript using `fetch` (reading the `ReadableStream` body) or `EventSource` to send user input to FastAPI and progressively append incoming SSE tokens to the right-hand output box in real time.

---

## Phase 3: Persistent Conversational Memory (MySQL)
**Goal:** Enable the system to explicitly store user facts in MySQL via a command prefix and automatically inject them as context on future prompts.

### User Stories & Tasks
- [ ] **Database Schema Initialization:** Create a `memories` table in MySQL (`id INT AUTO_INCREMENT PRIMARY KEY`, `content TEXT NOT NULL`, `created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP`).
- [ ] **Command Prefix Detection (`/remember <FACT>`):** In the FastAPI backend, check if the incoming prompt starts with `/remember `. If matched, strip the `/remember ` prefix, insert the remaining `<FACT>` string into the MySQL `memories` table, and return a confirmation message over the SSE stream without forwarding to Ollama.
- [ ] **Memory Retrieval & Prompt Injection:** On standard chat prompts (not starting with `/remember `), query MySQL for all stored rows in `memories`.
- [ ] **Context Formatting:** Format retrieved rows and prepend them to the outgoing Ollama prompt:
  ```text
  [Memory 1] - I am a scientist and like hamburgers
  [Memory 2] - <TEXT>
  
  User Prompt: <ORIGINAL_USER_PROMPT>
  ```
- [ ] **Debug/Transparency Output:** Ensure the final response (or a dedicated header/prefix in the stream) reflects or displays the prepended memory context so you can verify what was injected.

---

## Phase 4: Resume Ingestion Pipeline (Qdrant)
**Goal:** Build a standalone ingestion script to parse `.docx` resumes into overlapping line chunks and index them in Qdrant.

### User Stories & Tasks
- [ ] **Qdrant Collection Setup:** Initialize a Qdrant collection (e.g., `resumes`) configured for Cosine distance and matching the embedding dimensions of your Ollama embedding model (e.g., `768` for `nomic-embed-text`).
- [ ] **DOCX Text Extraction:** Write a Python script (`ingest_resume.py`) using `python-docx` to read all paragraphs/lines from a target `.docx` file cleanly.
- [ ] **Sliding Window Chunker:** Implement a line-based chunker that groups **30 lines per chunk** with a **10-line overlap** (step size = 20 lines) until the end of the document.
- [ ] **Embedding & Payload Storage:** For each chunk, generate a vector via Ollama's `/api/embeddings` endpoint and upsert a point into Qdrant containing:
  - **Point ID:** Unique UUID or deterministic hash
  - **Vector:** Cosine embedding array
  - **Payload Metadata:** `candidate_id`, `chunk_id`, `resume_filename`, and `chunk_text` (the raw 30 lines).
- [ ] **CLI Execution:** Make the script runnable via CLI arguments (e.g., `python ingest_resume.py --candidate-id "j_doe" --file "./resumes/john_doe.docx"`).

---

## Phase 5: RAG Candidate Search & Evaluation
**Goal:** Connect Qdrant semantic search to your FastAPI chat loop so you can query candidate skills using natural language.

### User Stories & Tasks
- [ ] **RAG Query Routing:** Update the FastAPI prompt router to detect candidate/skill queries (e.g., prompts matching `"Which candidate..."` or containing skill-search intent).
- [ ] **Vector Similarity Search:** Embed the user's query via Ollama and search the Qdrant `resumes` collection using Cosine similarity with a **`score_threshold=0.5`**.
- [ ] **Threshold Handling:**
  - If **matches > 0.5** are found: Retrieve the matching chunks and their metadata (`candidate_id`, `chunk_id`, `resume_filename`, `chunk_text`, and similarity `score`).
  - If **no matches > 0.5** are found: Return a clear fallback response stating no candidates met the `0.5` similarity threshold.
- [ ] **RAG Synthesis Response:** Pass the retrieved resume chunks and metadata into Ollama (or format them directly alongside Ollama's summary) so the SSE stream returns both the matching metadata and a synthesized answer identifying which candidate holds the requested skill.
