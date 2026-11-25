---
name: gpt-image
description: "GPT-Image-2 AI image generation and editing tool powered by OpenAI's gpt-image-2 model. Use this skill whenever the user wants to generate images from text prompts, edit existing images, apply style transfers, create variations, do inpainting with masks, or any visual content creation task. Trigger keywords include: draw, paint, generate image, create picture, text-to-image, image edit, style transfer, inpainting, AI art, illustration, photo manipulation, remove background, change style, add elements to image. Even if the user doesn't explicitly say 'generate image', if they describe a visual scene or ask for visual output, use this skill."
env:
  OPENAI_API_KEY:
    description: "OpenAI API Key with gpt-image-2 access"
    required: true
  OPENAI_BASE_URL:
    description: "Custom OpenAI API base URL (for proxies or Azure)"
    required: false
---

# GPT-Image-2 AI Image Generation & Editing

Generate and edit images using OpenAI's `gpt-image-2` model via the standard OpenAI Images API.

## Dependencies

### Runtime Requirements

| Dependency | Version | Purpose |
|-----------|---------|---------|
| Python | >= 3.10 | Script runtime (uses `match` syntax and modern type hints) |
| `openai` (PyPI) | >= 1.0.0 | OpenAI API client library |

Install the Python dependency:
```bash
pip install openai
```

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | **Yes** | Your OpenAI API key with gpt-image-2 access |
| `OPENAI_BASE_URL` | No | Custom API base URL (for proxies, Azure OpenAI, or compatible services) |

#### Auto-loading from `.env` file

The script **automatically reads a `.env` file** from the current working directory (the directory where you run the command). This means you can put your credentials in a `.env` file without manually exporting them:

```bash
# .env (in your project root)
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxxxxxx
OPENAI_BASE_URL=https://your-proxy.example.com/v1
```

**Priority rules:**
- Explicit environment variables (e.g., `export OPENAI_API_KEY=...`) always take precedence over `.env` values
- The `.env` file only sets variables that are not already present in the environment
- If no `.env` file exists, the script falls back to reading from the environment as usual

**Supported `.env` syntax:**
- `KEY=value` — basic assignment
- `KEY="quoted value"` or `KEY='single quoted'` — quoted values (quotes stripped)
- Lines starting with `#` — comments (ignored)
- Blank lines — ignored

> **Tip:** Add `.env` to your `.gitignore` to avoid accidentally committing API keys.

### Pre-flight Check

Before first use, verify your setup:
```bash
# 1. Check Python version (need 3.10+)
python3 --version

# 2. Check openai package is installed
python3 -c "import openai; print(openai.__version__)"

# 3. Check API key is available (via env or .env file)
python3 -c "
import os, sys
sys.path.insert(0, '<skill-path>/scripts')
from generate import load_dotenv
load_dotenv()
key = os.environ.get('OPENAI_API_KEY', '')
print('API key configured:', 'Yes' if key else 'No - please set OPENAI_API_KEY')
"
```

## Capabilities

| Mode | What it does |
|------|-------------|
| **Text-to-Image** | Generate images from text prompts. Supports size, quality, format options. |
| **Image Editing** | Upload reference images + prompt to create edits, style transfers, composites. |
| **Inpainting** | Upload image + mask (transparent areas = edit zones) for localized editing. |

## Quick Reference

The skill bundles a single Python script (`scripts/generate.py`) that handles both generation and editing:

```bash
# Text-to-image (basic)
python <skill-path>/scripts/generate.py --prompt "a cat sitting on a rainbow"

# Text-to-image (with options)
python <skill-path>/scripts/generate.py --prompt "oil painting of a sunset" --size 1536x1024 --quality high

# Image editing (style transfer)
python <skill-path>/scripts/generate.py --prompt "convert to watercolor style" --image ./photo.jpg

# Image editing (multiple inputs)
python <skill-path>/scripts/generate.py --prompt "merge these into one scene" --image ./img1.jpg --image ./img2.jpg

# Inpainting with mask
python <skill-path>/scripts/generate.py --prompt "replace background with beach" --image ./photo.jpg --mask ./mask.png
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `--prompt` | Yes | - | Image description or edit instruction (Chinese/English) |
| `--image` | No | - | Input image path (repeatable; omit for text-to-image) |
| `--mask` | No | - | Mask image path for inpainting (transparent = edit area) |
| `--size` | No | 1024x1024 | Output size: `1024x1024`, `1536x1024`, `1024x1536`, `auto` |
| `--quality` | No | medium | Quality level: `low`, `medium`, `high` |
| `--n` | No | 1 | Number of images to generate (1-4) |
| `--output-dir` | No | . | Directory to save output images |
| `--no-save` | No | false | Output base64 only, don't save files |
| `--format` | No | png | Output format: `png`, `jpeg`, `webp` |
| `--background` | No | - | Background handling: `transparent`, `opaque`, `auto` |
| `--timeout` | No | 180 | Request timeout in seconds |

## Workflow Guidance

### Choosing mode

- **No `--image` flag** → text-to-image generation
- **With `--image`** → image editing (style transfer, compositing, modification)
- **With `--image` + `--mask`** → localized inpainting

### Prompt writing tips

GPT-Image-2 responds well to detailed, descriptive prompts. For best results:

- Be specific about style, mood, lighting, composition
- For edits, describe what you want the result to look like, not just what to change
- Chinese and English prompts both work well
- Longer, more descriptive prompts generally produce better results

### Size selection guide

| Use case | Recommended size |
|----------|-----------------|
| Social media posts, avatars | `1024x1024` |
| Landscape/banner images | `1536x1024` |
| Portrait/story format | `1024x1536` |
| Let the model decide | `auto` |

### Quality vs Speed tradeoff

| Quality | Speed | Best for |
|---------|-------|----------|
| `low` | ~5-10s | Quick drafts, iterations |
| `medium` | ~15-30s | General use (default) |
| `high` | ~30-90s | Final output, presentations |

## Output Format

The script prints progress to stderr and results to stdout:

```
[request] Calling GPT-Image-2 (gpt-image-2), mode: text-to-image ...
[response] Success, took 12.3s

===== Results =====
Image 1: ./gpt_image_20260507_153000_1.png (saved)
```

With `--no-save`:
```
Image 1 (base64): data:image/png;base64,iVBORw0KGgo...
```

## Important Notes

- Single requests can take up to ~2 minutes for high quality; the timeout defaults to 180s
- The mask image must have an alpha channel (PNG) — transparent pixels mark the area to edit
- When providing multiple images for editing, all images are sent together for the model to composite/reference
- The `--background transparent` option is useful for generating stickers, logos, or overlay graphics
- Requires `python3` (>= 3.10) with `openai` package installed (`pip install openai`). See the Dependencies section above for full setup details

## Error Handling

| Error | Likely cause | Fix |
|-------|-------------|-----|
| "OPENAI_API_KEY not set" | Missing API key | Set the env var or add it to `.env` file in your working directory |
| "openai package not installed" | Missing Python dependency | Run `pip install openai` |
| 401 Unauthorized | Invalid or expired key | Check/refresh your API key |
| 400 Bad Request | Invalid parameters or content policy | Adjust prompt or parameters |
| 404 Not Found | Proxy doesn't support this endpoint | Use official OpenAI API or check proxy compatibility |
| Timeout | Complex generation taking too long | Increase `--timeout` or lower `--quality` |

## Known Limitations

- Some OpenAI-compatible proxies (e.g., LiteLLM) may only support `/images/generations` but not `/images/edits`. If image editing returns 404, you're likely behind such a proxy. Text-to-image will still work.
- Image editing (`--image`) requires the proxy/API to support the multipart `/images/edits` endpoint.
- Single requests can take 30-90 seconds depending on quality level.

## Reference

For detailed API documentation, see `references/api-reference.md`.
