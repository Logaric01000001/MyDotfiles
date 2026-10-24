"""Content Studio local: miniaturas, subtítulos y vídeo con FFmpeg + ImageMagick."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
from pathlib import Path

from . import common as c

FORMATS = {
    "short": (1080, 1920),
    "vertical": (1080, 1920),
    "wide": (1920, 1080),
    "youtube": (1920, 1080),
    "square": (1080, 1080),
    "carousel": (1080, 1350),
}

VIDEO_EXTS = {".mp4", ".mov", ".mkv", ".webm", ".m4v"}
IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".avif", ".bmp"}
AUDIO_EXTS = {".mp3", ".wav", ".m4a", ".aac", ".flac", ".ogg"}
DEFAULT_BRAND = {
    "name": "Mi Marca",
    "handle": "@mimarca",
    "tagline": "",
    "colors": {
        "bg": "#0b1020",
        "bg2": "#1b2a4a",
        "accent": "#ffb020",
        "text": "#ffffff",
        "muted": "#c9d3e6",
    },
    "fonts": {"title": "DejaVu Sans:bold", "body": "Noto Sans"},
    "logo": None,
}


# --------------------------------------------------------------------------
# base
# --------------------------------------------------------------------------

def root() -> Path:
    settings = c.load_json(c.SETTINGS_FILE, {})
    return Path(settings.get("content_root", str(c.HOME / "Contenido"))).expanduser()


def project(slug: str) -> Path:
    path = root() / slug
    if not path.is_dir():
        c.die(f"proyecto no encontrado: {path}. Créalo con: sc-kit content new {slug}")
    return path


def _tools() -> tuple[str, str]:
    magick = c.which("magick")
    ffmpeg = c.which("ffmpeg")
    if not magick:
        c.die("falta ImageMagick 7 (magick). Instálalo con: sudo pacman -S imagemagick --noconfirm")
    if not ffmpeg:
        c.die("falta ffmpeg. Instálalo con: sudo pacman -S ffmpeg --noconfirm")
    return magick, ffmpeg


def _font(preferred: str) -> str:
    fc = c.which("fc-match")
    if fc:
        proc = c.run([fc, "-f", "%{file}", preferred], timeout=15)
        if proc.returncode == 0 and proc.stdout.strip() and Path(proc.stdout.strip()).is_file():
            return proc.stdout.strip()
    for candidate in ("/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
                      "/usr/share/fonts/TTF/DejaVuSans.ttf"):
        if Path(candidate).is_file():
            return candidate
    c.die("no se encontró ninguna fuente TTF utilizable")


def _brand(path: Path) -> dict:
    brand = json.loads(json.dumps(DEFAULT_BRAND))
    data = c.load_json(path / "brand.json", {})
    brand.update({k: v for k, v in data.items() if k != "colors" and k != "fonts"})
    brand["colors"].update(data.get("colors") or {})
    brand["fonts"].update(data.get("fonts") or {})
    return brand


def _wrap(text: str, width: int) -> str:
    words, lines, current = text.split(), [], ""
    for word in words:
        if not current:
            current = word
        elif len(current) + 1 + len(word) <= width:
            current += " " + word
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def _text_layer(name: str, text: str, width: int, size: int, color: str,
                font: str, out: Path, chars: int, align: str = "center") -> Path:
    magick, _ = _tools()
    wrapped = _wrap(text, chars)
    text_file = out / f".{name}.txt"
    text_file.write_text(wrapped, encoding="utf-8")
    target = out / f"{name}.png"
    proc = c.run([magick, "-background", "none", "-fill", color, "-font", font,
                  "-pointsize", str(size), "-size", f"{width}x", "-gravity", align,
                  f"caption:@{text_file}", str(target)], timeout=120)
    if proc.returncode != 0:
        c.die(f"ImageMagick falló generando texto: {proc.stderr[-400:]}")
    text_file.unlink(missing_ok=True)
    return target


def _base_image(out: Path, width: int, height: int, brand: dict,
                image: Path | None, name: str) -> Path:
    magick, _ = _tools()
    target = out / f"{name}-base.png"
    colors = brand["colors"]
    proc = c.run([magick, "-size", f"{width}x{height}",
                  f"gradient:{colors['bg']}-{colors['bg2']}", str(target)], timeout=60)
    if proc.returncode != 0:
        c.die(f"ImageMagick falló: {proc.stderr[-300:]}")
    if image and image.is_file():
        proc = c.run([magick, str(target), str(image), "-resize", f"{width}x{height}^",
                      "-gravity", "center", "-extent", f"{width}x{height}",
                      "-compose", "over", "-composite", str(target)], timeout=120)
        if proc.returncode == 0:
            c.run([magick, str(target), "-fill", "black", "-colorize", "48%", str(target)],
                  timeout=60)
    # textura suave para evitar bandas en degradados
    c.run([magick, str(target), "-attenuate", "0.18", "+noise", "Gaussian",
           "-blur", "0x0.6", str(target)], timeout=120)
    return target


def _compose(base: Path, layers: list[tuple[Path, str, str]], out: Path) -> Path:
    magick, _ = _tools()
    cmd = [magick, str(base)]
    for layer, gravity, offset in layers:
        if offset:
            cmd += ["(", str(layer), ")", "-gravity", gravity,
                    "-geometry", offset, "-compose", "over", "-composite"]
        else:
            cmd += ["(", str(layer), ")", "-gravity", gravity,
                    "-compose", "over", "-composite"]
    cmd += ["-depth", "8", "-strip", "-quality", "92", str(out)]
    proc = c.run(cmd, timeout=180)
    if proc.returncode != 0:
        c.die(f"ImageMagick falló al componer: {proc.stderr[-400:]}")
    return out


# --------------------------------------------------------------------------
# comandos
# --------------------------------------------------------------------------

def cmd_new(slug: str, title: str | None = None, fmt: str = "short") -> int:
    base = root() / c.slugify(slug)
    if base.exists():
        c.die(f"ya existe {base}")
    for sub in ("assets", "audio", "out"):
        (base / sub).mkdir(parents=True)
    c.save_json(base / "brand.json", DEFAULT_BRAND)
    c.save_json(base / "scenes.json", {
        "format": fmt,
        "scenes": [
            {"text": "Gancho: el problema en una frase", "duration": 3.0},
            {"text": "Contexto y por qué importa", "duration": 4.0},
            {"text": "Demostración o evidencia", "duration": 5.0},
            {"text": "Conclusión y llamada a la acción", "duration": 3.0},
        ],
    })
    (base / "brief.md").write_text(
        f"# {title or slug}\n\n"
        "## Objetivo\n\n## Audiencia\n\n## Gancho (3 s)\n\n"
        "## Guion\n\n## Recursos necesarios\n\n## CTA\n\n"
        "## Referencias reales\n", encoding="utf-8")
    (base / "README.md").write_text(
        f"# {title or slug}\n\n"
        "1. Edita `brand.json` (colores, tipografías, handle).\n"
        "2. Coloca imágenes/vídeos en `assets/`.\n"
        "3. Ajusta `scenes.json` (texto y duración por escena).\n"
        "4. Previsualiza el plan: `sc-kit content render . --dry-run`\n"
        "5. Renderiza: `sc-kit content render .`\n"
        "6. Miniatura: `sc-kit content thumb . --title \"...\"`\n",
        encoding="utf-8")
    print(f"{c.ok('creado')} {base}")
    return 0


def cmd_list() -> int:
    folder = root()
    if not folder.is_dir():
        print(c.dim(f"no existe {folder}; crea el primero con: sc-kit content new mi-video"))
        return 0
    rows = []
    for item in sorted(folder.iterdir()):
        if not item.is_dir():
            continue
        scenes = c.load_json(item / "scenes.json", {}).get("scenes", [])
        output = item / "out" / "video.mp4"
        rows.append([item.name, str(len(scenes)),
                     f"{output.stat().st_size / 1e6:.1f} MB" if output.exists() else "-"])
    c.table(rows, ["proyecto", "escenas", "render"])
    return 0


def cmd_thumb(target: str, *, title: str | None = None, kicker: str | None = None,
              fmt: str = "short", image: str | None = None, output: str | None = None) -> int:
    base = project(target) if not Path(target).expanduser().is_dir() else Path(target).expanduser()
    if fmt not in FORMATS:
        c.die(f"formato desconocido: {fmt}. Usa: {', '.join(FORMATS)}")
    width, height = FORMATS[fmt]
    brand = _brand(base)
    title = title or brand.get("tagline") or base.name.replace("-", " ").title()
    kicker = kicker or brand.get("handle", "")
    image_path = Path(image).expanduser() if image else _first(base / "assets", IMAGE_EXTS)
    out = base / "out"
    out.mkdir(parents=True, exist_ok=True)
    tmp = out / ".tmp-thumb"
    tmp.mkdir(exist_ok=True)
    try:
        font_title = _font(brand["fonts"]["title"])
        font_body = _font(brand["fonts"]["body"])
        base_img = _base_image(tmp, width, height, brand, image_path, "thumb")
        margin = int(width * 0.085)
        title_size = int(min(width, height) * (0.105 if fmt in {"wide", "youtube"} else 0.085))
        title_layer = _text_layer(
            "title", title, width - 2 * margin, title_size, brand["colors"]["text"],
            font_title, tmp, chars=max(14, int((width - 2 * margin) / (title_size * 0.56))))
        kicker_layer = _text_layer(
            "kicker", kicker, width - 2 * margin, int(title_size * 0.34),
            brand["colors"]["accent"], font_body, tmp, chars=40, align="west")
        layers = [
            (kicker_layer, "northwest", f"+{margin}+{int(height * 0.12)}"),
            (title_layer, "south", f"+0+{int(height * 0.20)}"),
        ]
        logo = brand.get("logo")
        if logo and Path(logo).expanduser().is_file():
            layers.append((Path(logo).expanduser(), "southeast", f"+{margin}+{margin}"))
        final = out / (output or f"thumb-{fmt}.jpg")
        _compose(base_img, layers, final)
        # barra de acento
        magick, _ = _tools()
        c.run([magick, str(final), "-fill", brand["colors"]["accent"], "-draw",
               f"rectangle {margin},{int(height * 0.105)} "
               f"{margin + int(width * 0.16)},{int(height * 0.105) + max(6, height // 200)}",
               "-depth", "8", "-strip", "-quality", "92", str(final)], timeout=60)
        print(f"{c.ok('miniatura')} {final} ({width}x{height})")
        return 0
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def _first(folder: Path, exts: set[str]) -> Path | None:
    if not folder.is_dir():
        return None
    for item in sorted(folder.iterdir()):
        if item.suffix.lower() in exts:
            return item
    return None


def _srt_time(seconds: float) -> str:
    ms = int(round(seconds * 1000))
    h, ms = divmod(ms, 3600_000)
    m, ms = divmod(ms, 60_000)
    s, ms = divmod(ms, 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"


def _ass_time(seconds: float) -> str:
    cs = int(round(seconds * 100))
    h, cs = divmod(cs, 360_000)
    m, cs = divmod(cs, 6_000)
    s, cs = divmod(cs, 100)
    return f"{h}:{m:02d}:{s:02d}.{cs:02d}"


def _captions(scenes: list[dict], width_chars: int) -> list[tuple[float, float, str]]:
    cues: list[tuple[float, float, str]] = []
    cursor = 0.0
    for scene in scenes:
        duration = float(scene.get("duration", 3))
        text = (scene.get("text") or "").strip()
        if not text:
            cursor += duration
            continue
        parts = [p.strip() for p in re.split(r"(?<=[.!?])\s+", text) if p.strip()]
        if not parts:
            parts = [text]
        weights = [max(8, len(p)) for p in parts]
        total = sum(weights)
        start = cursor
        for part, weight in zip(parts, weights):
            span = duration * weight / total
            cues.append((start, start + span, _wrap(part, width_chars).replace("\n", "\\N")))
            start += span
        cursor += duration
    return cues


def _write_subs(base: Path, cues: list[tuple[float, float, str]],
                size: int, height: int) -> tuple[Path, Path]:
    out = base / "out"
    out.mkdir(parents=True, exist_ok=True)
    srt = out / "captions.srt"
    ass = out / "captions.ass"
    blocks = []
    for index, (start, end, text) in enumerate(cues, 1):
        blocks.append(f"{index}\n{_srt_time(start)} --> {_srt_time(end)}\n"
                      f"{text.replace(chr(92) + 'N', chr(10))}\n")
    srt.write_text("\n".join(blocks), encoding="utf-8")
    header = f"""[Script Info]
ScriptType: v4.00+
PlayResX: 1080
PlayResY: {height}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Default,DejaVu Sans,{size},&H00FFFFFF,&H000000FF,&H00101010,&H80000000,-1,0,0,0,100,100,0,0,1,4,2,2,70,70,{int(height*0.11)},1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    events = "\n".join(
        f"Dialogue: 0,{_ass_time(start)},{_ass_time(end)},Default,,0,0,0,,{text}"
        for start, end, text in cues)
    ass.write_text(header + events + "\n", encoding="utf-8")
    return srt, ass


def cmd_subs(target: str) -> int:
    base = project(target)
    data = c.load_json(base / "scenes.json", {})
    scenes = data.get("scenes", [])
    width, height = FORMATS.get(data.get("format", "short"), FORMATS["short"])
    cues = _captions(scenes, width_chars=22 if height > width else 42)
    srt, ass = _write_subs(base, cues, size=64 if height > width else 44, height=height)
    print(f"{c.ok('subtítulos')} {srt}")
    print(f"{c.dim('ass:')} {ass} ({len(cues)} cues)")
    return 0


def _probe_duration(ffprobe: str, path: Path) -> float:
    proc = c.run([ffprobe, "-v", "error", "-show_entries", "format=duration",
                  "-of", "default=nw=1:nk=1", str(path)], timeout=60)
    try:
        return float(proc.stdout.strip())
    except ValueError:
        return 0.0


def _canvas_layer(tmp: Path, name: str, text: str, width: int, height: int,
                  size: int, color: str, font: str, chars: int) -> Path:
    """Texto centrado en un lienzo transparente del tamaño del vídeo."""
    magick, _ = _tools()
    margin = int(width * 0.09)
    caption = _text_layer(name, text, width - 2 * margin, size, color, font,
                          tmp, chars=chars)
    canvas = tmp / f"{name}-canvas.png"
    proc = c.run([magick, "-size", f"{width}x{height}", "xc:none",
                  str(caption), "-gravity", "center", "-compose", "over",
                  "-composite", str(canvas)], timeout=120)
    if proc.returncode != 0:
        c.die(f"ImageMagick falló creando el lienzo: {proc.stderr[-300:]}")
    return canvas


def cmd_render(target: str, *, fmt: str | None = None, dry_run: bool = False,
               no_subs: bool = False, crf: int = 23, preset: str = "veryfast") -> int:
    magick, ffmpeg = _tools()
    base = project(target) if not Path(target).expanduser().is_dir() else Path(target).expanduser()
    data = c.load_json(base / "scenes.json", {})
    scenes = data.get("scenes") or []
    if not scenes:
        c.die("scenes.json no contiene escenas")
    fmt = fmt or data.get("format", "short")
    width, height = FORMATS.get(fmt, FORMATS["short"])
    brand = _brand(base)
    font = _font(brand["fonts"]["title"])
    out = base / "out"
    out.mkdir(parents=True, exist_ok=True)

    plan = []
    for index, scene in enumerate(scenes, 1):
        media = scene.get("image") or scene.get("video")
        media_path = (base / media).resolve() if media else None
        if media_path and not media_path.exists():
            c.die(f"escena {index}: no existe {media_path}")
        if not media_path:
            media_path = _first(base / "assets", IMAGE_EXTS)
        plan.append({
            "index": index,
            "text": scene.get("text", ""),
            "overlay": scene.get("overlay") or (scene.get("text", "") if no_subs else None),
            "duration": float(scene.get("duration", 3)),
            "media": media_path,
            "is_video": bool(media_path and media_path.suffix.lower() in VIDEO_EXTS),
        })

    total = sum(item["duration"] for item in plan)
    print(c.bold(f"{base.name} → {width}x{height} · {total:.1f}s · {len(plan)} escenas"))
    for item in plan:
        print(f"  {item['index']:>2}. {item['duration']:.1f}s  "
              f"{(item['media'].name if item['media'] else '(color)')}  "
              f"{item['text'][:48]}")
    if dry_run:
        print(c.dim("\nprevisualización: no se ha renderizado nada"))
        return 0

    tmp = out / ".tmp-render"
    shutil.rmtree(tmp, ignore_errors=True)
    tmp.mkdir(parents=True)
    clips = []
    try:
        for item in plan:
            clip = tmp / f"scene-{item['index']:02d}.mp4"
            chain = (f"scale={width}:{height}:force_original_aspect_ratio=increase,"
                     f"crop={width}:{height},setsar=1,fps=30,format=yuv420p")
            cmd = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error"]
            if item["media"] and item["is_video"]:
                cmd += ["-t", f"{item['duration']:.3f}", "-i", str(item["media"])]
            elif item["media"]:
                cmd += ["-loop", "1", "-framerate", "30", "-t", f"{item['duration']:.3f}",
                        "-i", str(item["media"])]
            else:
                cmd += ["-f", "lavfi", "-t", f"{item['duration']:.3f}", "-i",
                        f"color=c={brand['colors']['bg']}:s={width}x{height}:r=30"]
            if item["overlay"]:
                size = int(min(width, height) * (0.075 if height >= width else 0.062))
                margin = int(width * 0.09)
                layer = _canvas_layer(
                    tmp, f"scene-{item['index']}", item["overlay"], width, height, size,
                    brand["colors"]["text"], font,
                    max(14, int((width - 2 * margin) / (size * 0.58))))
                cmd += ["-i", str(layer)]
                filters = f"[0:v]{chain}[base];[base][1:v]overlay=0:0[v]"
            else:
                filters = f"[0:v]{chain}[v]"
            cmd += ["-filter_complex", filters, "-map", "[v]",
                    "-c:v", "libx264", "-preset", preset, "-crf", str(crf),
                    "-pix_fmt", "yuv420p", "-r", "30", "-an", str(clip)]
            proc = c.run(cmd, timeout=600)
            if proc.returncode != 0:
                c.die(f"ffmpeg falló en escena {item['index']}: {proc.stderr[-500:]}")
            clips.append(clip)
            print(c.dim(f"  escena {item['index']}/{len(plan)} lista"))

        concat_list = tmp / "clips.txt"
        concat_list.write_text("".join(f"file '{clip}'\n" for clip in clips),
                               encoding="utf-8")
        video = tmp / "video.mp4"
        proc = c.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                      "-f", "concat", "-safe", "0", "-i", str(concat_list),
                      "-c", "copy", str(video)], timeout=600)
        if proc.returncode != 0:
            c.die(f"ffmpeg falló al concatenar: {proc.stderr[-400:]}")

        cues = _captions(scenes, width_chars=22 if height > width else 42)
        srt, ass = _write_subs(base, cues, size=64 if height > width else 44, height=height)
        if cues and not no_subs:
            subtitled = tmp / "video-subs.mp4"
            proc = c.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                          "-i", str(video), "-vf", f"ass={ass.name}", "-c:v", "libx264",
                          "-preset", preset, "-crf", str(crf), "-pix_fmt", "yuv420p",
                          "-c:a", "copy", str(subtitled)], timeout=900, cwd=base / "out")
            if proc.returncode == 0:
                video = subtitled
            else:
                print(c.warn(f"no se pudieron incrustar subtítulos: {proc.stderr[-200:]}"))

        voice = _first(base / "audio", AUDIO_EXTS)
        music = None
        for item in sorted((base / "audio").glob("*")) if (base / "audio").is_dir() else []:
            if item.suffix.lower() in AUDIO_EXTS and item != voice:
                music = item
                break
        final = out / "video.mp4"
        if voice:
            cmd = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                   "-i", str(video), "-i", str(voice)]
            filters = "[1:a]apad,volume=1.0[voice]"
            if music:
                cmd += ["-i", str(music)]
                filters += f";[2:a]volume=0.18[bed];[voice][bed]amix=inputs=2:duration=first[a]"
            else:
                filters += ";[voice]anull[a]"
            cmd += ["-filter_complex", filters, "-map", "0:v", "-map", "[a]",
                    "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", str(final)]
        else:
            cmd = [ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
                   "-i", str(video), "-c", "copy", "-movflags", "+faststart", str(final)]
        proc = c.run(cmd, timeout=900)
        if proc.returncode != 0:
            c.die(f"ffmpeg falló al finalizar: {proc.stderr[-400:]}")
        size = final.stat().st_size / 1e6
        print(f"\n{c.ok('render')} {final} ({size:.1f} MB, {total:.1f}s)")
        print(c.dim(f"subtítulos: {srt}"))
        if not voice:
            print(c.warn("sin narración: coloca audio/voice.mp3 o audio/voice.wav y vuelve a renderizar"))
        return 0
    finally:
        if os.environ.get("SC_KIT_KEEP"):
            print(c.warn(f"intermedios conservados en {tmp}"))
        else:
            shutil.rmtree(tmp, ignore_errors=True)


def cmd_carousel(target: str, texts: str | None = None) -> int:
    base = project(target) if not Path(target).expanduser().is_dir() else Path(target).expanduser()
    if texts:
        source = Path(texts).expanduser()
        if not source.is_absolute():
            source = base / source
    else:
        source = base / "brief.md"
    if not source.is_file():
        c.die(f"no existe {source}")
    raw = source.read_text(encoding="utf-8")
    slides = [s.strip() for s in re.split(r"^---$", raw, flags=re.M) if s.strip()]
    if len(slides) < 2:
        c.die("usa separadores '---' para dividir las diapositivas")
    out = base / "out"
    out.mkdir(parents=True, exist_ok=True)
    for index, slide in enumerate(slides, 1):
        title = slide.splitlines()[0].lstrip("# ").strip()
        code = cmd_thumb(str(base), title=title, fmt="carousel",
                         output=f"slide-{index:02d}.jpg")
        if code != 0:
            return code
    print(f"{c.ok('carrusel')} {len(slides)} diapositivas en {out}")
    return 0


def cmd_probe(path: str) -> int:
    ffprobe = c.which("ffprobe")
    if not ffprobe:
        c.die("falta ffprobe")
    media = Path(path).expanduser()
    if not media.is_file():
        c.die(f"no existe {media}")
    proc = c.run([ffprobe, "-v", "error", "-show_entries",
                  "format=duration,size,bit_rate:stream=codec_type,codec_name,width,height,"
                  "r_frame_rate,channels,sample_rate",
                  "-of", "json", str(media)], timeout=60)
    if proc.returncode != 0:
        c.die(proc.stderr[-300:])
    data = json.loads(proc.stdout)
    print(c.bold(str(media)))
    for stream in data.get("streams", []):
        details = " ".join(f"{k}={v}" for k, v in stream.items()
                           if k in {"codec_type", "codec_name", "width", "height",
                                    "r_frame_rate", "channels", "sample_rate"})
        print("  " + details)
    fmt = data.get("format", {})
    print(f"  duración={float(fmt.get('duration', 0)):.2f}s "
          f"tamaño={int(fmt.get('size', 0)) / 1e6:.1f}MB")
    return 0


def cmd_optimize(path: str) -> int:
    _, ffmpeg = _tools()
    media = Path(path).expanduser()
    if not media.is_file():
        c.die(f"no existe {media}")
    target = media.with_name(media.stem + "-web.mp4")
    proc = c.run([ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(media),
                  "-c:v", "libx264", "-preset", "slow", "-crf", "21",
                  "-c:a", "aac", "-b:a", "160k", "-movflags", "+faststart", str(target)],
                 timeout=1800)
    if proc.returncode != 0:
        c.die(proc.stderr[-400:])
    print(f"{c.ok('optimizado')} {target} "
          f"({media.stat().st_size / 1e6:.1f} → {target.stat().st_size / 1e6:.1f} MB)")
    return 0
