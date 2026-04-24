# Python

## Package Management

Prefer `uv` over `pip`/`pip3`/`python -m venv`:

- `uv pip install` over `pip install`
- `uv venv` over `python -m venv`
- `uv run` for one-off script execution

## Linting

`ruff check` — fast Python linter (replaces flake8, pylint, isort, etc.)

## Formatting

`ruff format` — fast Python formatter (replaces black)
