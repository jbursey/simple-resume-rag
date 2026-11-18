## Local Development Setup (WSL / Ubuntu)

1. **Install Python virtual environment support:**
   ```bash
   sudo apt update && sudo apt install -y python3-venv
   ```

2. **Create and activate a virtual environment:**
   ```bash
   python3 -m venv .venv
   source .venv/bin/activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure VS Code IntelliSense:**
   * Open the project inside WSL (`code .`).
   * Ensure the **Python** extension is installed in WSL.
   * Press `Ctrl + Shift + P`, select **Python: Select Interpreter**, and choose `.venv/bin/python`.