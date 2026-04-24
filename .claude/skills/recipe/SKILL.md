---
name: recipe
description: "Transcribe a recipe from a URL, image, or pasted text into the standard recipe format."
argument-hint: "<url, image path, or description>"
---

# Recipe Transcription

Transcribe a recipe into the notes vault at `~/notes/40-49 food-drink-other/41 recipes/`.

## Steps

### 1. Determine the next available number

Scan `~/notes/40-49 food-drink-other/41 recipes/` for the highest `41.XX` prefix:

```bash
ls "$HOME/notes/40-49 food-drink-other/41 recipes/" | grep -o '^41\.[0-9]*' | sort -t. -k2 -n | tail -1
```

Increment by 1 to get the next number (e.g., `41.30` → `41.31`). Zero-pad single digits (e.g., `41.05`).

### 2. Identify the recipe source

Parse the argument and conversation context to determine the source type:

- **URL**: Use WebFetch to retrieve the page, then extract the recipe (title, ingredients, instructions).
- **Image path** (file ending in `.png`, `.jpg`, `.jpeg`, `.webp`, `.heic`): Use the Read tool to view the image and transcribe the recipe from it.
- **Pasted text or conversation context**: Parse the recipe directly from what the user provided.

### 3. Archive source image

When the source is an image file, copy it to the recipes directory alongside the `.md` file:

- Naming: `41.XX recipe-name-source.<original-extension>` (matching the recipe's prefix and name)
- Example: recipe file `41.31 banana bread.md` sourced from `photo.jpg` → copy to `41.31 banana bread-source.jpg`
- Skip this step for URL, pasted text, or other non-image sources

### 4. Format the recipe

Use this exact template:

```markdown
---
id: 41.XX recipe-name
aliases: []
tags:
  - recipe/new
  - recipe/<category>
  - claude       # always
  - OCR          # only when source is an image
---

from <source>

## ingredients

- item 1
- item 2

## instructions

1. Step one.
2. Step two.
```

**Formatting rules:**
- `id` matches the filename without `.md`
- All headings are lowercase (`## ingredients`, not `## Ingredients`)
- Ingredients use bullet lists (`- item`)
- Instructions use numbered lists (`1. Step`)
- Multi-component recipes (dough + filling + sauce) use `### subsection` headings under `## ingredients`
- Preserve original measurements; include both metric and imperial if the source does
- Optional trailing sections (notes, modifications) are fine if they add value
- Strip ads, life stories, and non-recipe content from web sources

### 5. Source attribution

The line immediately after the closing `---` of frontmatter:

- **URL source**: `from <url>`
- **Person/book**: `from <name>` or `by way of <person>, transcribed from <url>`
- **Image source**: `from <description>` (e.g., `from cookbook photo`, or the book title if visible)
- **Conversation/pasted text**: `from <brief description of origin>`

### 6. Infer category tag

Choose the best-fit category tag based on recipe content:

| Tag | Use for |
|-----|---------|
| `recipe/meal` | Main dishes, entrees, soups, salads-as-a-meal |
| `recipe/dessert` | Sweets, baked goods, cakes, cookies, pies |
| `recipe/alcohol` | Cocktails, alcoholic drinks |
| `recipe/drink` | Non-alcoholic beverages (kombucha, smoothies) |
| `recipe/breakfast` | Breakfast-specific (overnight oats, scones can be both breakfast and dessert) |
| `recipe/side` | Side dishes, condiments, pickles, bread, marmalade |

Multiple category tags are acceptable (e.g., `recipe/breakfast` + `recipe/dessert` for scones).
Always include `recipe/new` in addition to the category tag(s).
Always include `claude`.
When the source is an image, also include `OCR`.

### 7. Derive filename

- Format: `41.XX recipe-name.md`
- Recipe name in lowercase, words separated by spaces (matching existing convention)
- Keep it concise but descriptive

### 8. Write the file

Write to `~/notes/40-49 food-drink-other/41 recipes/41.XX recipe-name.md`.

### 9. Report

Print:
- File path
- Recipe name
- Ingredient count
- Step count

Then open the new recipe file using `/open <file-path>`.
