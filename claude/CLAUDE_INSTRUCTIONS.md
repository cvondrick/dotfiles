# Common Claude Instructions

## Python Development
- ALWAYS use `uv` for Python package management instead of pip
  - Use `uv pip install` instead of `pip install`
  - Use `uv venv` to create virtual environments
  - Use `uv pip sync requirements.txt` for dependency management
- ALWAYS use the `rich` library for enhanced terminal output in Python scripts
  - Use `from rich.console import Console; console = Console()`
  - Use `console.print()` instead of `print()` for colored output
  - Use `rich.progress` for progress bars
  - Use `rich.table` for formatted tables

## Code Style Preferences
- NO EMOJIS in code, comments, commit messages, or responses
- Use descriptive variable names
- Follow existing code conventions in the repository
- Prefer explicit over implicit
- Prefer straightforward solutions
- Add type hints to Python functions
- Put random scripts in a `scripts` directory

## File Operations
- Always check if a file exists before creating a new one
- Prefer editing existing files over creating new ones
- Never create documentation files unless explicitly requested

## Tool Usage
- Web fetches are always allowed - use freely for documentation lookups
- Use `uv` for all Python package operations
- Run commands in parallel when possible for better performance
