# GPT-Image-2 API Reference

## Overview

GPT-Image-2 uses the standard OpenAI Images API with two main endpoints:
- **`/v1/images/generations`** — Text-to-image (JSON request body)
- **`/v1/images/edits`** — Image editing (multipart/form-data)

Official docs: https://platform.openai.com/docs/api-reference/images

---

## Authentication

```
Authorization: Bearer {OPENAI_API_KEY}
```

---

## 1. Image Generation — POST /v1/images/generations

### Request

```json
{
  "model": "gpt-image-2",
  "prompt": "A photograph of a red fox in an autumn forest",
  "size": "1024x1024",
  "quality": "medium",
  "n": 1,
  "output_format": "png",
  "background": "auto"
}
```

### Parameters

| Parameter | Type | Required | Default | Values |
|-----------|------|----------|---------|--------|
| `model` | string | Yes | - | `gpt-image-2` |
| `prompt` | string | Yes | - | Image description |
| `n` | int | No | 1 | 1-4 |
| `size` | string | No | 1024x1024 | `1024x1024`, `1536x1024`, `1024x1536`, `auto` |
| `quality` | string | No | medium | `low`, `medium`, `high` |
| `output_format` | string | No | png | `png`, `jpeg`, `webp` |
| `output_compression` | int | No | - | 0-100 (jpeg/webp only) |
| `background` | string | No | auto | `transparent`, `opaque`, `auto` |
| `moderation` | string | No | auto | `low`, `auto` |

### Response

```json
{
  "created": 1757496455,
  "data": [
    {
      "b64_json": "iVBORw0KGgoAAAANSUhEUgAAA..."
    }
  ],
  "usage": {
    "total_tokens": 1234,
    "input_tokens": 100,
    "output_tokens": 1134,
    "input_tokens_details": { "text_tokens": 50, "image_tokens": 50 },
    "output_tokens_details": { "image_tokens": 1134 }
  }
}
```

---

## 2. Image Editing — POST /v1/images/edits

### Request (multipart/form-data)

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `model` | string | Yes | `gpt-image-2` |
| `prompt` | string | Yes | Edit instruction |
| `image` | file(s) | Yes | Input image(s) — use `image[]` for multiple |
| `mask` | file | No | Mask PNG with alpha channel |
| `n` | int | No | Number of outputs (1-4) |
| `size` | string | No | Output size |
| `quality` | string | No | Quality level |

### Mask format

- Must be PNG with alpha channel
- Transparent pixels (alpha=0) mark areas to edit
- Opaque pixels mark areas to preserve
- Must match the dimensions of the first input image

### Response

Same format as generation endpoint.

---

## 3. Streaming (Advanced)

GPT-Image-2 supports streaming partial images via the Responses API:

```json
POST /v1/responses
{
  "model": "gpt-5",
  "input": "Generate an image of a sunset",
  "tools": [{"type": "image_generation"}],
  "stream": true
}
```

This returns SSE events including `partial_image` events for progressive preview.
The bundled script does NOT use streaming — it uses the simpler synchronous endpoints.

---

## Python SDK Examples

### Text-to-image

```python
from openai import OpenAI
import base64

client = OpenAI()

response = client.images.generate(
    model="gpt-image-2",
    prompt="A cute baby sea otter floating on its back",
    size="1024x1024",
    quality="medium",
    n=1,
)

b64 = response.data[0].b64_json
with open("output.png", "wb") as f:
    f.write(base64.b64decode(b64))
```

### Image editing

```python
from openai import OpenAI
import base64

client = OpenAI()

with open("photo.png", "rb") as img:
    response = client.images.edit(
        model="gpt-image-2",
        image=img,
        prompt="Add a rainbow in the sky",
        size="1024x1024",
    )

b64 = response.data[0].b64_json
with open("edited.png", "wb") as f:
    f.write(base64.b64decode(b64))
```

### Image editing with mask

```python
from openai import OpenAI
import base64

client = OpenAI()

with open("photo.png", "rb") as img, open("mask.png", "rb") as mask:
    response = client.images.edit(
        model="gpt-image-2",
        image=img,
        mask=mask,
        prompt="A beautiful garden with flowers",
        size="1024x1024",
    )

b64 = response.data[0].b64_json
with open("inpainted.png", "wb") as f:
    f.write(base64.b64decode(b64))
```

---

## Error Codes

| HTTP Status | Meaning |
|-------------|---------|
| 200 | Success |
| 400 | Invalid request (bad params, content policy violation) |
| 401 | Invalid API key |
| 403 | Insufficient permissions |
| 429 | Rate limit exceeded |
| 500 | Server error |

---

## Pricing Notes (as of 2026)

- Pricing is per-image based on quality and size
- `low` quality is cheapest, `high` is most expensive
- Larger sizes cost more
- Multiple images (n>1) multiply the per-image cost
