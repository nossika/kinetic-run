#!/usr/bin/env python3
"""GPT-Image-2 generation and editing tool.

Uses the OpenAI Images API (standard) to generate images from text prompts
or edit existing images with optional masks.

Requirements:
    Python >= 3.10
    pip install openai

Environment:
    OPENAI_API_KEY   - Required. Your OpenAI API key.
    OPENAI_BASE_URL  - Optional. Custom base URL for proxies/Azure.

    Environment variables are auto-loaded from .env file in the current
    working directory (if it exists). Explicit env vars take precedence.

Usage:
    # Text-to-image
    python generate.py --prompt "a beautiful sunset over mountains"

    # Text-to-image with options
    python generate.py --prompt "cyberpunk city" --size 1536x1024 --quality high --n 2

    # Image editing
    python generate.py --prompt "make it watercolor style" --image ./photo.jpg

    # Multiple image inputs
    python generate.py --prompt "combine into one scene" --image ./a.jpg --image ./b.jpg

    # Inpainting with mask
    python generate.py --prompt "replace with ocean" --image ./photo.jpg --mask ./mask.png

    # Output base64 only (no file save)
    python generate.py --prompt "a cat" --no-save

    # Custom output format
    python generate.py --prompt "logo design" --format png --background transparent
"""

import argparse
import base64
import os
import sys
import time
from datetime import datetime
from pathlib import Path


def load_dotenv():
    """Load environment variables from .env file in the current working directory.

    Only sets variables that are not already defined in the environment,
    so explicit env vars always take precedence over .env values.

    Supports:
      - KEY=value
      - KEY="quoted value"
      - KEY='single quoted value'
      - Comments (#) and blank lines are ignored
      - Inline comments after unquoted values
    """
    env_path = Path.cwd() / ".env"
    if not env_path.is_file():
        return

    try:
        with open(env_path, "r", encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                # Skip empty lines and comments
                if not line or line.startswith("#"):
                    continue
                # Must contain = sign
                if "=" not in line:
                    continue

                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip()

                # Skip invalid key names
                if not key or " " in key:
                    continue

                # Handle quoted values
                if (value.startswith('"') and value.endswith('"')) or \
                   (value.startswith("'") and value.endswith("'")):
                    value = value[1:-1]
                else:
                    # Strip inline comments for unquoted values
                    comment_idx = value.find(" #")
                    if comment_idx != -1:
                        value = value[:comment_idx].strip()

                # Only set if not already in environment (explicit env takes precedence)
                if key not in os.environ:
                    os.environ[key] = value
    except OSError:
        pass  # Silently ignore read errors


# Auto-load .env before anything else
load_dotenv()


try:
    from openai import OpenAI
except ImportError:
    print(
        "Error: openai package not installed. Run: pip install openai",
        file=sys.stderr,
    )
    sys.exit(1)


VALID_SIZES = ["1024x1024", "1536x1024", "1024x1536", "auto"]
VALID_QUALITIES = ["low", "medium", "high"]
VALID_FORMATS = ["png", "jpeg", "webp"]
VALID_BACKGROUNDS = ["transparent", "opaque", "auto"]


def create_client() -> OpenAI:
    """Create an OpenAI client from environment variables."""
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        print(
            "Error: OPENAI_API_KEY not set. Please set it in your environment.",
            file=sys.stderr,
        )
        sys.exit(1)

    kwargs = {"api_key": api_key}
    base_url = os.environ.get("OPENAI_BASE_URL")
    if base_url:
        kwargs["base_url"] = base_url

    return OpenAI(**kwargs)


def generate_image(
    client: OpenAI,
    prompt: str,
    size: str = "1024x1024",
    quality: str = "medium",
    n: int = 1,
    output_format: str = "png",
    background: str | None = None,
    timeout: float = 180.0,
) -> list[dict]:
    """Generate images from a text prompt.

    Returns a list of dicts with 'b64' and 'format' keys.
    """
    print(f"[request] Calling GPT-Image-2 (gpt-image-2), mode: text-to-image ...", file=sys.stderr)
    start = time.time()

    params = {
        "model": "gpt-image-2",
        "prompt": prompt,
        "n": n,
    }
    if size != "auto":
        params["size"] = size
    if quality != "medium":
        params["quality"] = quality
    if output_format != "png":
        params["output_format"] = output_format
    if background:
        params["background"] = background

    response = client.images.generate(**params, timeout=timeout)
    elapsed = time.time() - start
    print(f"[response] Success, took {elapsed:.1f}s", file=sys.stderr)

    results = []
    for item in response.data:
        b64 = item.b64_json
        if b64:
            results.append({"b64": b64, "format": output_format})

    if not results:
        print("Warning: model returned no images", file=sys.stderr)

    return results


def edit_image(
    client: OpenAI,
    prompt: str,
    images: list[str],
    mask: str | None = None,
    size: str = "1024x1024",
    quality: str = "medium",
    n: int = 1,
    timeout: float = 180.0,
) -> list[dict]:
    """Edit images with a prompt and optional mask.

    Returns a list of dicts with 'b64' and 'format' keys.
    """
    # Validate input files
    for img_path in images:
        if not os.path.isfile(img_path):
            print(f"Error: image file not found: {img_path}", file=sys.stderr)
            sys.exit(1)
    if mask and not os.path.isfile(mask):
        print(f"Error: mask file not found: {mask}", file=sys.stderr)
        sys.exit(1)

    mode = "inpainting" if mask else "image editing"
    print(f"[request] Calling GPT-Image-2 (gpt-image-2), mode: {mode} ...", file=sys.stderr)
    start = time.time()

    # Open image files
    image_files = [open(p, "rb") for p in images]
    mask_file = open(mask, "rb") if mask else None

    try:
        params = {
            "model": "gpt-image-2",
            "prompt": prompt,
            "image": image_files if len(image_files) > 1 else image_files[0],
            "n": n,
        }
        if size != "auto":
            params["size"] = size
        if quality != "medium":
            params["quality"] = quality
        if mask_file:
            params["mask"] = mask_file

        response = client.images.edit(**params, timeout=timeout)
    finally:
        for f in image_files:
            f.close()
        if mask_file:
            mask_file.close()

    elapsed = time.time() - start
    print(f"[response] Success, took {elapsed:.1f}s", file=sys.stderr)

    results = []
    for item in response.data:
        b64 = item.b64_json
        if b64:
            results.append({"b64": b64, "format": "png"})

    if not results:
        print("Warning: model returned no images", file=sys.stderr)

    return results


def save_images(results: list[dict], output_dir: str) -> list[str]:
    """Save base64-encoded images to files. Returns list of saved paths."""
    os.makedirs(output_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    saved = []

    for i, item in enumerate(results, 1):
        ext = item["format"]
        filename = f"gpt_image_{timestamp}_{i}.{ext}"
        filepath = os.path.join(output_dir, filename)

        raw_bytes = base64.b64decode(item["b64"])
        with open(filepath, "wb") as f:
            f.write(raw_bytes)

        saved.append(filepath)

    return saved


def main():
    parser = argparse.ArgumentParser(
        description="GPT-Image-2: Generate and edit images with AI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python generate.py --prompt "a cat on a rainbow"
  python generate.py --prompt "oil painting style" --image ./photo.jpg
  python generate.py --prompt "replace sky" --image ./photo.jpg --mask ./mask.png
  python generate.py --prompt "logo" --format png --background transparent --quality high
        """,
    )
    parser.add_argument(
        "--prompt", required=True,
        help="Image description or edit instruction",
    )
    parser.add_argument(
        "--image", action="append", default=None,
        help="Input image path (repeatable; omit for text-to-image)",
    )
    parser.add_argument(
        "--mask", default=None,
        help="Mask image path for inpainting (transparent = edit area)",
    )
    parser.add_argument(
        "--size", default="1024x1024", choices=VALID_SIZES,
        help="Output image size (default: 1024x1024)",
    )
    parser.add_argument(
        "--quality", default="medium", choices=VALID_QUALITIES,
        help="Image quality level (default: medium)",
    )
    parser.add_argument(
        "--n", type=int, default=1, choices=range(1, 5), metavar="N",
        help="Number of images to generate, 1-4 (default: 1)",
    )
    parser.add_argument(
        "--format", default="png", choices=VALID_FORMATS,
        help="Output image format (default: png)",
    )
    parser.add_argument(
        "--background", default=None, choices=VALID_BACKGROUNDS,
        help="Background handling (only for text-to-image)",
    )
    parser.add_argument(
        "--output-dir", default=".",
        help="Directory to save output images (default: current dir)",
    )
    parser.add_argument(
        "--no-save", action="store_true",
        help="Don't save files, only output base64",
    )
    parser.add_argument(
        "--timeout", type=float, default=180.0,
        help="Request timeout in seconds (default: 180)",
    )

    args = parser.parse_args()

    prompt = args.prompt.strip()
    if not prompt:
        print("Error: prompt cannot be empty", file=sys.stderr)
        sys.exit(1)

    client = create_client()

    # Choose mode based on whether images are provided
    if args.image:
        results = edit_image(
            client=client,
            prompt=prompt,
            images=args.image,
            mask=args.mask,
            size=args.size,
            quality=args.quality,
            n=args.n,
            timeout=args.timeout,
        )
    else:
        results = generate_image(
            client=client,
            prompt=prompt,
            size=args.size,
            quality=args.quality,
            n=args.n,
            output_format=args.format,
            background=args.background,
            timeout=args.timeout,
        )

    # Output results
    print("\n===== Results =====")

    if not results:
        print("No images generated. Try adjusting your prompt.", file=sys.stderr)
        sys.exit(1)

    if args.no_save:
        for i, item in enumerate(results, 1):
            mime = f"image/{item['format']}"
            data_url = f"data:{mime};base64,{item['b64'][:60]}..."
            print(f"Image {i} (base64): {data_url}")
            # Also print full base64 for programmatic use
            print(f"Image {i} full base64 length: {len(item['b64'])} chars")
    else:
        saved_paths = save_images(results, args.output_dir)
        for i, path in enumerate(saved_paths, 1):
            abs_path = str(Path(path).resolve())
            print(f"Image {i}: {abs_path} (saved)")


if __name__ == "__main__":
    main()
