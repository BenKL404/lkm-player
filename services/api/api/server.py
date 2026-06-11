"""
API REST exposant la logique de téléchargement Telegramusic (Deezer, YouTube, SoundCloud).
Utilisable depuis une app Flutter ou tout client HTTP sans passer par le bot Telegram.

Usage:
  Depuis la racine du projet (où se trouve token.env) :
    python -m uvicorn api.server:app --host 0.0.0.0 --port 8000
  Les variables de token.env (DEEZER_TOKEN, TELEGRAM_TOKEN, etc.) sont chargées automatiquement.
"""

import asyncio
import functools
import os
import re
from pathlib import Path
from typing import List, Optional, Dict, Any

# Charger token.env avant tout import qui utilise os.environ (ex: handlers.deezer)
def _load_token_env():
    root = Path(__file__).resolve().parent.parent
    env_path = root / "token.env"
    if env_path.exists():
        with open(env_path, encoding="utf-8") as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, _, value = line.partition("=")
                    os.environ.setdefault(key.strip(), value.strip())

_load_token_env()

from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query, Path as FastAPIPath, BackgroundTasks, APIRouter, Security, Depends
from fastapi.security.api_key import APIKeyHeader
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response, StreamingResponse
from pydantic import BaseModel, Field

# Import de la logique métier (handlers.deezer initialise la session Deezer au chargement)
from handlers.deezer import (
    download_album,
    download_playlist,
    download_track,
    get_album_metadata_from_api,
    get_playlist_metadata_from_api,
    get_track_metadata_from_api,
)
from dl_utils.deezer_download import (
    TYPE_ALBUM,
    TYPE_TRACK,
    deezer_search,
    get_song_url,
    calcbfkey,
    blowfishDecrypt,
    session as deezer_session,
)
from dl_utils.yt_download import download_yt_dlp, yt_dlp_search
from utils import TMP_DIR, SimpleTTLCache, SimpleAsyncTTLCache

# Sémaphore pour limiter le nombre de téléchargements concurrents côté API
MAX_CONCURRENT_DOWNLOADS = int(os.environ.get("MAX_CONCURRENT_DOWNLOADS", "3"))
_download_semaphore = asyncio.Semaphore(MAX_CONCURRENT_DOWNLOADS)

# Caches pour l'API REST
# Métadonnées (durée de vie : 10 minutes)
metadata_cache = SimpleTTLCache(600)
get_track_metadata_from_api = metadata_cache.decorator(get_track_metadata_from_api)
get_album_metadata_from_api = metadata_cache.decorator(get_album_metadata_from_api)
get_playlist_metadata_from_api = metadata_cache.decorator(get_playlist_metadata_from_api)

# Recherches (durée de vie : 5 minutes)
search_cache = SimpleAsyncTTLCache(300)

# Authentification optionnelle par clé API
API_KEY_NAME = "X-API-Key"
api_key_header = APIKeyHeader(name=API_KEY_NAME, auto_error=False)

async def verify_api_key(header_value: str = Security(api_key_header)):
    expected_key = os.environ.get("API_KEY")
    if expected_key and header_value != expected_key:
        raise HTTPException(
            status_code=403,
            detail="Forbidden: Invalid or missing API Key"
        )


# ---------- Modèles de données Pydantic (OpenAPI Schemas) ----------

class DeezerSearchResult(BaseModel):
    id: str = Field(..., description="ID unique du titre ou de l'album Deezer")
    id_type: str = Field(..., description="Le type de ressource ('track' ou 'album')")
    title: str = Field(..., description="Titre du morceau ou nom de l'album")
    artist: str = Field(..., description="Nom de l'artiste principal")
    album: Optional[str] = Field(None, description="Nom de l'album (si titre)")
    img_url: Optional[str] = Field(None, description="URL de la pochette")

class YtdlSearchResult(BaseModel):
    id: str = Field(..., description="ID unique de la vidéo YouTube ou du titre SoundCloud")
    id_type: str = Field(..., description="Le service d'origine ('youtube' ou 'soundcloud')")
    title: str = Field(..., description="Titre de la piste ou de la vidéo")
    artist: str = Field(..., description="Nom de la chaîne ou de l'artiste")
    img_url: Optional[str] = Field(None, description="URL de la miniature")
    url: str = Field(..., description="Lien direct vers la source")
    duration: Optional[int] = Field(None, description="Durée de la piste en secondes")

class AlbumTrack(BaseModel):
    id: str = Field(..., description="ID unique du morceau Deezer")
    id_type: str = Field("track", description="Le type de ressource")
    title: str = Field(..., description="Titre du morceau")
    artist: str = Field(..., description="Artiste du morceau")
    album: str = Field(..., description="Titre de l'album associé")
    album_id: str = Field(..., description="ID unique de l'album associé")
    img_url: Optional[str] = Field(None, description="URL de la pochette")
    preview_url: Optional[str] = Field(None, description="URL de l'extrait audio (preview)")

class AlbumTracksResponse(BaseModel):
    album_id: str = Field(..., description="ID de l'album Deezer")
    album_title: str = Field(..., description="Titre de l'album")
    artist: str = Field(..., description="Artiste principal de l'album")
    tracks: List[AlbumTrack] = Field(..., description="Liste des pistes de l'album")

class DeezerGlobalResults(BaseModel):
    tracks: List[DeezerSearchResult] = Field(..., description="Liste des titres trouvés sur Deezer")
    albums: List[DeezerSearchResult] = Field(..., description="Liste des albums trouvés sur Deezer")

class GlobalSearchResponse(BaseModel):
    source: str = Field(..., description="Source ciblée ('all', 'deezer', 'youtube', 'soundcloud')")
    deezer: Optional[DeezerGlobalResults] = Field(None, description="Résultats Deezer (présents si source='all' ou 'deezer')")
    youtube: Optional[List[YtdlSearchResult]] = Field(None, description="Résultats YouTube (présents si source='all' ou 'youtube')")
    soundcloud: Optional[List[YtdlSearchResult]] = Field(None, description="Résultats SoundCloud (présents si source='all' ou 'soundcloud')")


# ---------- Initialisation FastAPI ----------

def _clean_temp_dir():
    try:
        import shutil
        tmp_path = Path(TMP_DIR)
        if tmp_path.exists():
            for child in tmp_path.iterdir():
                if child.is_dir():
                    shutil.rmtree(child, ignore_errors=True)
                else:
                    child.unlink(missing_ok=True)
            print("Nettoyage au démarrage terminé avec succès.", flush=True)
    except Exception as e:
        print(f"Erreur lors du nettoyage au démarrage: {e}", flush=True)

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Nettoyage du dossier de téléchargement temporaire...", flush=True)
    _clean_temp_dir()
    yield

app = FastAPI(
    title="Telegramusic API",
    description=(
        "API REST complète, versionnée et harmonisée pour chercher et télécharger de la musique depuis Deezer, YouTube et SoundCloud.\n\n"
        "### Fonctionnalités principales :\n"
        "- 🔍 **Recherche unifiée `/api/v1/search`** : Permet de requêter toutes les sources ou une source spécifique avec pagination.\n"
        "- 📥 **Téléchargements cohérents** : Fichiers MP3 ou archives ZIP groupés par fournisseur (Deezer, YouTube, SoundCloud).\n"
        "- ⚡ **Gestion de la concurrence** via un sémaphore global pour préserver les ressources.\n"
        "- 🧹 **Nettoyage automatique** du disque après chaque téléchargement via des tâches d'arrière-plan."
    ),
    version="2.0.0",
    contact={
        "name": "BenKL404",
        "url": "https://github.com/BenKL404/lkm-player",
    },
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routeur versionné (V1) avec authentification optionnelle
router = APIRouter(prefix="/api/v1", dependencies=[Depends(verify_api_key)])

# Regex pour valider les IDs / liens Deezer
TRACK_REGEX = re.compile(r"https?://(?:www\.)?deezer\.com/([a-z]*/)?track/(\d+)/?$")
ALBUM_REGEX = re.compile(r"https?://(?:www\.)?deezer\.com/([a-z]*/)?album/(\d+)/?$")
PLAYLIST_REGEX = re.compile(r"https?://(?:www\.)?deezer\.com/([a-z]*/)?playlist/(\d+)/?$")


def _extract_id(link: str | None, regex: re.Pattern) -> str | None:
    if not link or not link.strip():
        return None
    link = link.strip()
    if link.isdigit():
        return link
    m = regex.search(link)
    return m.group(2) if m else None


def _cleanup_path(path_to_clean: Path):
    """Nettoie de manière sécurisée un fichier ou un répertoire temporaire."""
    try:
        import shutil
        if path_to_clean.exists():
            if path_to_clean.is_dir():
                shutil.rmtree(path_to_clean, ignore_errors=True)
            else:
                path_to_clean.unlink(missing_ok=True)
            print(f"Nettoyage réussi pour {path_to_clean}", flush=True)
    except Exception as e:
        print(f"Erreur lors du nettoyage de {path_to_clean}: {e}", flush=True)


# Le nettoyage au démarrage est désormais géré par le gestionnaire de contexte lifespan


# ---------- Fonctions d'Aide pour Recherche Parallèle ----------

@search_cache.decorator
async def _search_deezer_safe(query: str, search_type: str) -> list:
    try:
        loop = asyncio.get_running_loop()
        return await loop.run_in_executor(
            None, functools.partial(deezer_search, query, search_type)
        )
    except Exception as e:
        print(f"Search - Deezer {search_type} error: {e}", flush=True)
        return []

@search_cache.decorator
async def _search_youtube_safe(query: str, limit: int) -> list:
    try:
        return await yt_dlp_search(query, service="youtube", max_results=limit)
    except Exception as e:
        print(f"Search - YouTube error: {e}", flush=True)
        return []

@search_cache.decorator
async def _search_soundcloud_safe(query: str, limit: int) -> list:
    try:
        return await yt_dlp_search(query, service="soundcloud", max_results=limit)
    except Exception as e:
        print(f"Search - SoundCloud error: {e}", flush=True)
        return []


# ---------- Recherche Unifiée (V1) ----------

@router.get(
    "/search",
    summary="Recherche unifiée multi-sources",
    description=(
        "Recherche de musique sur Deezer, YouTube ou SoundCloud.\n\n"
        "- Si `provider` est 'all' (par défaut), effectue les recherches en parallèle sur toutes les sources et retourne un aperçu limité de chaque source (idéal pour l'affichage initial).\n"
        "- Si `provider` est spécifique (ex: 'youtube'), effectue uniquement la recherche pour cette source et retourne les résultats correspondants."
    ),
    tags=["Recherche"],
    response_model=GlobalSearchResponse,
)
async def search(
    q: str = Query(..., min_length=1, description="Texte de recherche (ex: 'Adele Hello')"),
    provider: str = Query("all", regex="^(all|deezer|youtube|soundcloud)$", description="Source cible de la recherche"),
    type: str = Query("track", regex="^(track|album)$", description="Type de recherche (uniquement pour Deezer)"),
    limit: Optional[int] = Query(None, ge=1, le=50, description="Nombre maximum de résultats retournés (défaut : 5 par source si 'all', 20 si source spécifique)"),
):
    query = q.strip()
    if not query:
        raise HTTPException(status_code=400, detail="Requête vide")

    # Détermine la limite par défaut selon le provider
    default_limit = 5 if provider == "all" else 20
    actual_limit = limit if limit is not None else default_limit

    if provider == "all":
        # Lance toutes les recherches en parallèle
        dz_tracks_task = _search_deezer_safe(query, TYPE_TRACK)
        dz_albums_task = _search_deezer_safe(query, TYPE_ALBUM)
        yt_task = _search_youtube_safe(query, actual_limit)
        sc_task = _search_soundcloud_safe(query, actual_limit)

        dz_tracks, dz_albums, yt_results, sc_results = await asyncio.gather(
            dz_tracks_task, dz_albums_task, yt_task, sc_task
        )

        return {
            "source": "all",
            "deezer": {
                "tracks": dz_tracks[:actual_limit],
                "albums": dz_albums[:actual_limit]
            },
            "youtube": yt_results[:actual_limit],
            "soundcloud": sc_results[:actual_limit]
        }

    elif provider == "deezer":
        search_type = TYPE_ALBUM if type == "album" else TYPE_TRACK
        dz_results = await _search_deezer_safe(query, search_type)
        
        if type == "album":
            return {
                "source": "deezer",
                "deezer": {
                    "tracks": [],
                    "albums": dz_results[:actual_limit]
                }
            }
        else:
            return {
                "source": "deezer",
                "deezer": {
                    "tracks": dz_results[:actual_limit],
                    "albums": []
                }
            }

    elif provider == "youtube":
        yt_results = await _search_youtube_safe(query, actual_limit)
        return {
            "source": "youtube",
            "youtube": yt_results[:actual_limit]
        }

    elif provider == "soundcloud":
        sc_results = await _search_soundcloud_safe(query, actual_limit)
        return {
            "source": "soundcloud",
            "soundcloud": sc_results[:actual_limit]
        }


# ---------- Deezer - Métadonnées & Pochettes (V1) ----------

@router.get(
    "/deezer/track/{track_id}/meta",
    summary="Obtenir les métadonnées d'un morceau Deezer",
    description="Récupère les détails d'un morceau Deezer sans télécharger le fichier audio.",
    tags=["Deezer - Métadonnées & Pochettes"],
    response_model=Dict[str, Any],
)
def track_meta(
    track_id: str = FastAPIPath(..., description="ID unique du morceau Deezer ou URL complète"),
):
    tid = _extract_id(track_id, TRACK_REGEX) or track_id
    try:
        meta = get_track_metadata_from_api(tid)
        out = {k: v for k, v in meta.items() if k != "cover_data"}
        if meta.get("cover_data"):
            out["cover_url"] = f"/api/v1/deezer/track/{tid}/cover"
        return out
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/deezer/album/{album_id}/meta",
    summary="Obtenir les métadonnées d'un album Deezer",
    description="Récupère les détails d'un album Deezer sans le télécharger.",
    tags=["Deezer - Métadonnées & Pochettes"],
    response_model=Dict[str, Any],
)
def album_meta(
    album_id: str = FastAPIPath(..., description="ID unique de l'album Deezer ou URL complète"),
):
    aid = _extract_id(album_id, ALBUM_REGEX) or album_id
    try:
        meta = get_album_metadata_from_api(aid)
        out = {k: v for k, v in meta.items() if k != "cover_data"}
        if meta.get("cover_data"):
            out["cover_url"] = f"/api/v1/deezer/album/{aid}/cover"
        return out
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/deezer/album/{album_id}/tracks",
    summary="Obtenir les pistes d'un album Deezer",
    description="Récupère la liste structurée des pistes d'un album Deezer pour affichage sur le client mobile.",
    tags=["Deezer - Métadonnées & Pochettes"],
    response_model=AlbumTracksResponse,
)
def album_tracks(
    album_id: str = FastAPIPath(..., description="ID unique de l'album Deezer ou URL complète"),
):
    aid = _extract_id(album_id, ALBUM_REGEX) or album_id
    try:
        meta = get_album_metadata_from_api(aid)
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))
    album_title = meta.get("title", "")
    album_artist = meta.get("artist", "Unknown Artist")
    album_cover = meta.get("api_json", {})
    cover_url = (
        album_cover.get("cover_small")
        or album_cover.get("cover_medium")
        or ""
    )
    tracks_raw = meta.get("tracks_api_data", [])
    tracks = []
    for t in tracks_raw:
        artist = t.get("artist", {})
        artist_name = artist.get("name", album_artist) if isinstance(artist, dict) else album_artist
        tracks.append({
            "id": str(t.get("id", "")),
            "id_type": "track",
            "title": t.get("title", ""),
            "artist": artist_name,
            "album": album_title,
            "album_id": aid,
            "img_url": cover_url,
            "preview_url": t.get("preview", ""),
        })
    return {
        "album_id": aid,
        "album_title": album_title,
        "artist": album_artist,
        "tracks": tracks,
    }


@router.get(
    "/deezer/playlist/{playlist_id}/meta",
    summary="Obtenir les métadonnées d'une playlist Deezer",
    description="Récupère les détails d'une playlist Deezer sans la télécharger.",
    tags=["Deezer - Métadonnées & Pochettes"],
    response_model=Dict[str, Any],
)
def playlist_meta(
    playlist_id: str = FastAPIPath(..., description="ID unique de la playlist Deezer ou URL complète"),
):
    pid = _extract_id(playlist_id, PLAYLIST_REGEX) or playlist_id
    try:
        meta = get_playlist_metadata_from_api(pid)
        out = {k: v for k, v in meta.items() if k != "cover_data"}
        if meta.get("cover_data"):
            out["cover_url"] = f"/api/v1/deezer/playlist/{pid}/cover"
        return out
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/deezer/track/{track_id}/cover",
    summary="Récupérer la pochette d'un morceau Deezer",
    description="Retourne directement le fichier image (JPEG) de la pochette d'un morceau Deezer.",
    tags=["Deezer - Métadonnées & Pochettes"],
    responses={
        200: {"content": {"image/jpeg": {}}, "description": "Fichier image JPEG de la pochette."}
    },
)
def track_cover(
    track_id: str = FastAPIPath(..., description="ID unique du morceau Deezer ou URL complète"),
):
    tid = _extract_id(track_id, TRACK_REGEX) or track_id
    try:
        meta = get_track_metadata_from_api(tid)
        cover = meta.get("cover_data")
        if not cover:
            raise HTTPException(status_code=404, detail="Pas de pochette")
        return Response(content=cover, media_type="image/jpeg")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@app.get(
    "/api/deezer/album/{album_id}/cover",
    deprecated=True,
    include_in_schema=False
)
@router.get(
    "/deezer/album/{album_id}/cover",
    summary="Récupérer la pochette d'un album Deezer",
    description="Retourne directement le fichier image (JPEG) de la pochette d'un album Deezer.",
    tags=["Deezer - Métadonnées & Pochettes"],
    responses={
        200: {"content": {"image/jpeg": {}}, "description": "Fichier image JPEG de la pochette."}
    },
)
def album_cover(
    album_id: str = FastAPIPath(..., description="ID unique de l'album Deezer ou URL complète"),
):
    aid = _extract_id(album_id, ALBUM_REGEX) or album_id
    try:
        meta = get_album_metadata_from_api(aid)
        cover = meta.get("cover_data")
        if not cover:
            raise HTTPException(status_code=404, detail="Pas de pochette")
        return Response(content=cover, media_type="image/jpeg")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get(
    "/deezer/playlist/{playlist_id}/cover",
    summary="Récupérer la pochette d'une playlist Deezer",
    description="Retourne directement le fichier image (JPEG) de la pochette d'une playlist Deezer.",
    tags=["Deezer - Métadonnées & Pochettes"],
    responses={
        200: {"content": {"image/jpeg": {}}, "description": "Fichier image JPEG de la pochette."}
    },
)
def playlist_cover(
    playlist_id: str = FastAPIPath(..., description="ID unique de la playlist Deezer ou URL complète"),
):
    pid = _extract_id(playlist_id, PLAYLIST_REGEX) or playlist_id
    try:
        meta = get_playlist_metadata_from_api(pid)
        cover = meta.get("cover_data")
        if not cover:
            raise HTTPException(status_code=404, detail="Pas de pochette")
        return Response(content=cover, media_type="image/jpeg")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=404, detail=str(e))


# ---------- Téléchargements (Deezer) (V1) ----------

@router.get(
    "/deezer/track/{track_id}/download",
    summary="Télécharger un morceau Deezer",
    description="Télécharge un morceau individuel depuis Deezer et renvoie le fichier audio (MP3 ou FLAC).",
    tags=["Téléchargements"],
    response_class=FileResponse,
)
async def download_track_file(
    track_id: str = FastAPIPath(..., description="ID unique du morceau Deezer ou URL complète"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    tid = _extract_id(track_id, TRACK_REGEX) or track_id
    async with _download_semaphore:
        try:
            dl_info = await download_track(tid)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))
        if not dl_info or "song_path" not in dl_info:
            raise HTTPException(status_code=502, detail="Échec du téléchargement")
        song_path = Path(dl_info["song_path"])
        if not song_path.exists():
            raise HTTPException(status_code=502, detail="Fichier non trouvé")
        filename = f"{dl_info.get('artist_name', 'Artist')} - {dl_info.get('song_name', tid)}{dl_info.get('file_extension', '.mp3')}"
        filename = re.sub(r'[<>:"/\\|?*]', "_", filename)
        base_dir = dl_info.get("download_dir")

        if base_dir:
            background_tasks.add_task(_cleanup_path, Path(base_dir))

        return FileResponse(
            path=str(song_path),
            filename=filename,
            media_type="audio/mpeg" if song_path.suffix == ".mp3" else "audio/flac",
        )


@router.get(
    "/deezer/album/{album_id}/download",
    summary="Télécharger un album Deezer complet en ZIP",
    description="Télécharge l'intégralité des pistes d'un album Deezer et retourne une archive ZIP compressée.",
    tags=["Téléchargements"],
    response_class=FileResponse,
)
async def download_album_zip(
    album_id: str = FastAPIPath(..., description="ID unique de l'album Deezer ou URL complète"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    aid = _extract_id(album_id, ALBUM_REGEX) or album_id
    async with _download_semaphore:
        try:
            dl_tracks = await download_album(aid)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))
        if not dl_tracks:
            raise HTTPException(status_code=502, detail="Aucune piste téléchargée")
        try:
            metadata = get_album_metadata_from_api(aid)
        except Exception:
            metadata = {"title": f"Album_{aid}", "artist": "Unknown"}
        from zipfile import ZIP_DEFLATED, ZipFile
        from dl_utils.deezer_utils import clean_filename

        source_dir = Path(dl_tracks[0]["download_dir"])
        safe_name = clean_filename(f"{metadata.get('artist', 'Artist')} - {metadata.get('title', aid)}")
        zip_path = Path(TMP_DIR) / "api" / f"{safe_name}.zip"
        zip_path.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(zip_path, "w", ZIP_DEFLATED) as zf:
            for t in sorted(dl_tracks, key=lambda x: int(x.get("TRACK_NUMBER", 999))):
                p = Path(t["song_path"])
                if p.exists():
                    name = p.name
                    zf.write(p, name)
        if not zip_path.exists():
            raise HTTPException(status_code=502, detail="Échec création ZIP")

        background_tasks.add_task(_cleanup_path, zip_path)
        background_tasks.add_task(_cleanup_path, source_dir)

        return FileResponse(
            path=str(zip_path),
            filename=f"{safe_name}.zip",
            media_type="application/zip",
        )


@router.get(
    "/deezer/playlist/{playlist_id}/download",
    summary="Télécharger une playlist Deezer en ZIP",
    description="Télécharge l'intégralité des pistes d'une playlist Deezer et retourne une archive ZIP compressée.",
    tags=["Téléchargements"],
    response_class=FileResponse,
)
async def download_playlist_zip(
    playlist_id: str = FastAPIPath(..., description="ID unique de la playlist Deezer ou URL complète"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    pid = _extract_id(playlist_id, PLAYLIST_REGEX) or playlist_id
    async with _download_semaphore:
        try:
            dl_tracks = await download_playlist(pid)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))
        if not dl_tracks:
            raise HTTPException(status_code=502, detail="Aucune piste téléchargée")
        try:
            metadata = get_playlist_metadata_from_api(pid)
        except Exception:
            metadata = {"title": f"Playlist_{pid}", "artist": "Unknown"}
        from zipfile import ZIP_DEFLATED, ZipFile
        from dl_utils.deezer_utils import clean_filename

        source_dir = Path(dl_tracks[0]["download_dir"])
        safe_name = clean_filename(f"{metadata.get('artist', 'Artist')} - {metadata.get('title', pid)}")
        zip_path = Path(TMP_DIR) / "api" / f"{safe_name}.zip"
        zip_path.parent.mkdir(parents=True, exist_ok=True)
        with ZipFile(zip_path, "w", ZIP_DEFLATED) as zf:
            for t in dl_tracks:
                p = Path(t["song_path"])
                if p.exists():
                    zf.write(p, p.name)
        if not zip_path.exists():
            raise HTTPException(status_code=502, detail="Échec création ZIP")

        background_tasks.add_task(_cleanup_path, zip_path)
        background_tasks.add_task(_cleanup_path, source_dir)

        return FileResponse(
            path=str(zip_path),
            filename=f"{safe_name}.zip",
            media_type="application/zip",
        )


# ---------- Téléchargements (YouTube & SoundCloud) (V1) ----------

@router.get(
    "/youtube/{video_id}/download",
    summary="Télécharger le flux audio d'une vidéo YouTube",
    description="Télécharge et extrait l'audio d'une vidéo YouTube (MP3 en 320kbps), intègre la miniature et retourne le fichier audio.",
    tags=["Téléchargements"],
    response_class=FileResponse,
)
async def download_youtube(
    video_id: str = FastAPIPath(..., description="ID unique de la vidéo YouTube (ex: 'dQw4w9WgXcQ') ou URL complète"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    url = f"https://www.youtube.com/watch?v={video_id}" if not video_id.startswith("http") else video_id
    async with _download_semaphore:
        try:
            result = await download_yt_dlp(url, is_soundcloud=False)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))
        
        song_path = Path(result["song_path"])
        if not song_path.exists():
            raise HTTPException(status_code=502, detail="Fichier non trouvé")
        
        filename = f"{result['artist']} - {result['title']}.mp3"
        filename = re.sub(r'[<>:"/\\|?*]', "_", filename)
        
        background_tasks.add_task(_cleanup_path, song_path)
        
        return FileResponse(
            path=str(song_path),
            filename=filename,
            media_type="audio/mpeg",
        )


@router.get(
    "/soundcloud/download",
    summary="Télécharger un morceau SoundCloud",
    description="Télécharge un morceau SoundCloud en utilisant son URL complète et retourne le fichier audio (MP3 en 320kbps) étiqueté.",
    tags=["Téléchargements"],
    response_class=FileResponse,
)
async def download_soundcloud(
    url: str = Query(..., description="URL complète du titre SoundCloud (ex: 'https://soundcloud.com/artist/track')"),
    background_tasks: BackgroundTasks = BackgroundTasks(),
):
    async with _download_semaphore:
        try:
            result = await download_yt_dlp(url, is_soundcloud=True)
        except Exception as e:
            raise HTTPException(status_code=502, detail=str(e))
        
        song_path = Path(result["song_path"])
        if not song_path.exists():
            raise HTTPException(status_code=502, detail="Fichier non trouvé")
        
        filename = f"{result['artist']} - {result['title']}.mp3"
        filename = re.sub(r'[<>:"/\\|?*]', "_", filename)
        
        background_tasks.add_task(_cleanup_path, song_path)
        
        return FileResponse(
            path=str(song_path),
            filename=filename,
            media_type="audio/mpeg",
        )


# Inclure le routeur V1 dans l'application
app.include_router(router)


# ---------- Streaming (V1) ----------

def _get_deezer_stream_generator(song_id: str, track_token: str, format_name: str):
    """
    Générateur synchrone pour lire, décrypter bloc par bloc et diffuser
    un morceau Deezer en direct.
    """
    url = get_song_url(track_token, format_name)
    key = calcbfkey(song_id)
    
    # Nous utilisons la session Deezer globale pour récupérer le morceau en streaming
    with deezer_session.get(url, stream=True) as response:
        response.raise_for_status()
        i = 0
        block_size = 2048
        for chunk in response.iter_content(chunk_size=block_size):
            if not chunk:
                break
            
            is_encrypted = (i % 3) == 0
            is_whole_block = len(chunk) == block_size

            if is_encrypted and is_whole_block:
                chunk = blowfishDecrypt(chunk, key)
            
            yield chunk
            i += 1


@router.get(
    "/deezer/track/{track_id}/stream",
    summary="Diffuser un morceau Deezer en direct (Streaming)",
    description="Décrypte à la volée en mémoire et diffuse le flux audio d'un morceau Deezer sans écriture disque.",
    tags=["Streaming"],
)
async def stream_deezer_track(
    track_id: str = FastAPIPath(..., description="ID unique du morceau Deezer ou URL complète"),
    format: str = Query("MP3_128", regex="^(MP3_128|MP3_320|FLAC)$", description="Format audio demandé"),
):
    tid = _extract_id(track_id, TRACK_REGEX) or track_id
    try:
        # Récupération des métadonnées (bénéficie du cache TTL de 10 min)
        meta = get_track_metadata_from_api(tid)
        song_id = meta.get("SNG_ID")
        track_token = meta.get("TRACK_TOKEN")
        if not song_id or not track_token:
            raise HTTPException(status_code=404, detail="Impossible de récupérer les tokens de streaming du morceau")
        
        media_type = "audio/mpeg" if format != "FLAC" else "audio/flac"
        
        return StreamingResponse(
            _get_deezer_stream_generator(song_id, track_token, format),
            media_type=media_type,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Erreur de streaming : {str(e)}")


@router.get(
    "/youtube/{video_id}/stream",
    summary="Diffuser le flux audio d'une vidéo YouTube (Streaming)",
    description="Redirige en temps réel le flux audio d'une vidéo YouTube via yt-dlp.",
    tags=["Streaming"],
)
async def stream_youtube_track(
    video_id: str = FastAPIPath(..., description="ID de la vidéo YouTube (ex: 'dQw4w9WgXcQ') ou URL complète"),
):
    url = f"https://www.youtube.com/watch?v={video_id}" if not video_id.startswith("http") else video_id
    
    async def play_audio_stream():
        # Utiliser yt-dlp pour extraire le meilleur flux audio vers stdout
        cmd = [
            "yt-dlp",
            "-f", "bestaudio",
            "-o", "-",  # Écriture directe sur stdout
            url
        ]
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        
        try:
            while True:
                chunk = await process.stdout.read(4096)
                if not chunk:
                    break
                yield chunk
        finally:
            # S'assurer de terminer le processus proprement
            try:
                process.terminate()
            except ProcessLookupError:
                pass
            await process.wait()

    return StreamingResponse(play_audio_stream(), media_type="audio/webm")


@router.get(
    "/soundcloud/stream",
    summary="Diffuser un morceau SoundCloud (Streaming)",
    description="Redirige en temps réel le flux audio d'un morceau SoundCloud via yt-dlp.",
    tags=["Streaming"],
)
async def stream_soundcloud_track(
    url: str = Query(..., description="URL complète du titre SoundCloud"),
):
    async def play_audio_stream():
        cmd = [
            "yt-dlp",
            "-f", "bestaudio",
            "-o", "-",
            url
        ]
        process = await asyncio.create_subprocess_exec(
            *cmd,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL
        )
        
        try:
            while True:
                chunk = await process.stdout.read(4096)
                if not chunk:
                    break
                yield chunk
        finally:
            try:
                process.terminate()
            except ProcessLookupError:
                pass
            await process.wait()

    return StreamingResponse(play_audio_stream(), media_type="audio/webm")


# ---------- Accueil ----------

@app.get(
    "/",
    summary="Obtenir la liste des routes de l'API",
    description="Retourne une description simplifiée de l'état du service et des points d'accès disponibles.",
    tags=["Service"],
)
async def root():
    return {
        "service": "Telegramusic API",
        "docs": "/docs",
        "endpoints": {
            "search": "GET /api/v1/search?q=...&provider=all|deezer|youtube|soundcloud&limit=...",
            "deezer_track_meta": "GET /api/v1/deezer/track/{id}/meta",
            "deezer_track_cover": "GET /api/v1/deezer/track/{id}/cover",
            "deezer_track_download": "GET /api/v1/deezer/track/{id}/download",
            "deezer_track_stream": "GET /api/v1/deezer/track/{id}/stream?format=MP3_128|MP3_320|FLAC",
            "deezer_album_meta": "GET /api/v1/deezer/album/{id}/meta",
            "deezer_album_tracks": "GET /api/v1/deezer/album/{id}/tracks",
            "deezer_album_cover": "GET /api/v1/deezer/album/{id}/cover",
            "deezer_album_download": "GET /api/v1/deezer/album/{id}/download",
            "deezer_playlist_meta": "GET /api/v1/deezer/playlist/{id}/meta",
            "deezer_playlist_cover": "GET /api/v1/deezer/playlist/{id}/cover",
            "deezer_playlist_download": "GET /api/v1/deezer/playlist/{id}/download",
            "youtube_download": "GET /api/v1/youtube/{video_id}/download",
            "youtube_stream": "GET /api/v1/youtube/{video_id}/stream",
            "soundcloud_download": "GET /api/v1/soundcloud/download?url=...",
            "soundcloud_stream": "GET /api/v1/soundcloud/stream?url=...",
        },
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", "8000"))
    uvicorn.run(app, host="0.0.0.0", port=port)
