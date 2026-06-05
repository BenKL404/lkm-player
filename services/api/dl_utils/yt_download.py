import asyncio
import io
import os
import re
import requests
from pathlib import Path
from PIL import Image
from mutagen.id3 import ID3, error, APIC
from mutagen.mp3 import MP3
import yt_dlp
from yt_dlp import YoutubeDL
from utils import TMP_DIR

COOKIES_PATH = os.environ.get("COOKIES_PATH")
YT_TMP_DIR = Path(TMP_DIR, "yt")
SC_TMP_DIR = Path(TMP_DIR, "sc")

YT_TMP_DIR.mkdir(parents=True, exist_ok=True)
SC_TMP_DIR.mkdir(parents=True, exist_ok=True)


def crop_center(pil_img, crop_width, crop_height):
    img_width, img_height = pil_img.size
    return pil_img.crop(
        (
            (img_width - crop_width) // 2,
            (img_height - crop_height) // 2,
            (img_width + crop_width) // 2,
            (img_height + crop_height) // 2,
        )
    )


async def download_yt_dlp(url: str, is_soundcloud: bool = False) -> dict:
    """
    Downloads audio from YouTube or SoundCloud, extracts metadata,
    downloads and crops thumbnail, tags the MP3 file, and returns metadata and path.
    """
    tmp_dir = SC_TMP_DIR if is_soundcloud else YT_TMP_DIR
    ydl_opts = {
        "outtmpl": str(tmp_dir / "%(id)s.%(ext)s"),
        "format": "bestaudio/best",
        "postprocessors": [
            {
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": "320",
            }
        ],
        "quiet": True,
        "no_warnings": True,
    }

    if not is_soundcloud and COOKIES_PATH and os.path.exists(COOKIES_PATH) and os.path.isfile(COOKIES_PATH) and os.path.getsize(COOKIES_PATH) > 0:
        ydl_opts["cookiefile"] = COOKIES_PATH

    # Download file in executor
    ydl = YoutubeDL(ydl_opts)
    dict_info = await asyncio.to_thread(ydl.extract_info, url, download=True)
    if not dict_info:
        raise ValueError("Could not extract media info or download failed")

    track_id = dict_info.get("id", "unknown_id")
    location = tmp_dir / f"{track_id}.mp3"

    if not location.exists():
        raise FileNotFoundError(f"Expected audio file not found at {location}")

    # Extract metadata
    thumb_url = dict_info.get("thumbnail")
    if is_soundcloud:
        track_title = dict_info.get("track") or dict_info.get("title", "Unknown Title")
        uploader = dict_info.get("artist") or dict_info.get("uploader", "Unknown Artist")
    else:
        track_title = dict_info.get("title", "Unknown Title")
        uploader = dict_info.get("uploader", "Unknown Artist")

    webpage_url = dict_info.get("webpage_url", url)

    # Format upload date (YYYYMMDD to DD/MM/YYYY)
    upload_date_str = "Unknown date"
    upload_date = dict_info.get("upload_date")
    if upload_date and len(upload_date) == 8:
        try:
            upload_date_str = f"{upload_date[6:8]}/{upload_date[4:6]}/{upload_date[0:4]}"
        except Exception:
            pass

    # Download and process thumbnail
    image_bytes = None
    thumb_for_tagging = None
    thumb_for_sending = None
    if thumb_url:
        try:
            content = requests.get(thumb_url).content
            image_bytes = io.BytesIO(content)
            thumb_for_tagging = image_bytes.getvalue()

            # Create smaller thumbnail
            image_bytes.seek(0)
            roi_img = crop_center(Image.open(image_bytes), 80, 80)
            img_byte_arr = io.BytesIO()
            if roi_img.mode in ("RGBA", "P"):
                roi_img = roi_img.convert("RGB")
            roi_img.save(img_byte_arr, format="jpeg")
            thumb_for_sending = img_byte_arr.getvalue()
        except Exception as e:
            print(f"Error processing thumbnail for {url}: {e}")

    # Tag audio file
    try:
        audio = MP3(location, ID3=ID3)
        try:
            audio.add_tags()
        except error:
            pass  # Tags already exist
        if thumb_for_tagging and audio.tags:
            audio.tags.add(
                APIC(
                    mime="image/jpeg",
                    type=3,
                    desc="Cover",
                    data=thumb_for_tagging,
                )
            )
        audio.save()
    except Exception as e:
        print(f"Error tagging audio file {location}: {e}")

    return {
        "song_path": location,
        "title": track_title,
        "artist": uploader,
        "webpage_url": webpage_url,
        "upload_date": upload_date_str,
        "thumb_url": thumb_url,
        "cover_data": thumb_for_tagging,
        "thumb_small_data": thumb_for_sending,
        "temp_dir": tmp_dir,
    }


async def yt_dlp_search(query: str, service: str = "youtube", max_results: int = 15) -> list:
    """
    Searches YouTube or SoundCloud using yt-dlp and returns a list of formatted results.
    """
    ydl_opts = {
        "quiet": True,
        "no_warnings": True,
        "extract_flat": True,
        "skip_download": True,
    }
    prefix = "scsearch" if service == "soundcloud" else "ytsearch"
    search_query = f"{prefix}{max_results}:{query}"
    
    loop = asyncio.get_running_loop()
    with YoutubeDL(ydl_opts) as ydl:
        dict_info = await loop.run_in_executor(
            None, lambda: ydl.extract_info(search_query, download=False)
        )
    
    results = []
    if dict_info and "entries" in dict_info:
        for entry in dict_info["entries"]:
            if not entry:
                continue
            
            title = entry.get("title") or "Unknown Title"
            artist = entry.get("uploader") or entry.get("channel") or "Unknown Artist"
            if service == "soundcloud":
                if " - " in title:
                    parts = title.split(" - ", 1)
                    artist, title = parts[0], parts[1]

            duration_raw = entry.get("duration")
            duration_val = None
            if duration_raw is not None:
                try:
                    duration_val = int(float(duration_raw))
                except (ValueError, TypeError):
                    pass

            results.append({
                "id": entry.get("id") or "",
                "id_type": service,
                "title": title,
                "artist": artist,
                "img_url": entry.get("thumbnail") or "",
                "url": entry.get("url") or entry.get("webpage_url") or f"https://www.youtube.com/watch?v={entry.get('id')}",
                "duration": duration_val,
            })
    return results
