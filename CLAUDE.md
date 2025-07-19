# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a personal dotfiles repository for managing system configurations across machines. The repository contains configuration files for various development tools and uses symbolic links to deploy them to the appropriate locations.

## Key Files and Structure

- **setup.sh**: Main installation script that creates symbolic links from this repository to system locations
- **activate_claude.sh**: Sets up environment variables for Claude Code with AWS Bedrock integration
- Configuration files:
  - `.tmux.conf`: tmux terminal multiplexer configuration
  - `.zshrc`: Zsh shell configuration (requires Oh My Zsh)
  - `.vimrc`: Vim editor configuration
  - `init.lua`: Neovim configuration (main config file)
  - `kitty.conf`: Kitty terminal emulator configuration
  - `ssh.config`: SSH client configuration
  - `.prettierrc.json`: Prettier code formatter configuration
  - `.gitconfig`: Git configuration with user info, colors, diff/merge tools, and custom aliases
- **myplugins/**: Custom Neovim Lua plugins including GPT integration and tmux interaction tools
- **fonts/**: Custom Monego and Monaco Nerd Font variants

## Common Commands

### Initial Setup
```bash
./setup.sh
```
This script:
- Creates necessary directories (~/.config/nvim, ~/.config/kitty)
- Creates symbolic links for all configuration files
- Clones tmux plugin manager (tpm)
- Installs Zsh plugins (syntax-highlighting, autosuggestions)
- Installs vim-plug for Vim

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
