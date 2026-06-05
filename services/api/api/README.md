# API REST Telegramusic

API HTTP permettant d'utiliser la logique de recherche et de téléchargement de musique (Deezer, YouTube, SoundCloud) **depuis une application externe** (ex: Flutter, LKM Player) sans passer par le bot Telegram.

## Prérequis

- `DEEZER_TOKEN` : cookie ARL Deezer (requis uniquement pour Deezer, voir [Finding Your Deezer ARL Cookie](https://github.com/nathom/streamrip/wiki/Finding-Your-Deezer-ARL-Cookie))
- `COOKIES_PATH` : chemin optionnel vers un fichier `cookies.txt` pour contourner le blocage de YouTube
- Optionnel : `TELEGRAM_TOKEN` uniquement si vous lancez aussi le bot Telegram

## Démarrer l’API

Depuis la racine du projet :

```bash
# Windows (PowerShell)
$env:DEEZER_TOKEN = "votre_arl_cookie"
python -m uvicorn api.server:app --host 0.0.0.0 --port 8000

# Linux / macOS
export DEEZER_TOKEN=your_arl_cookie
python -m uvicorn api.server:app --host 0.0.0.0 --port 8000
```

- **Docs interactives Swagger** : http://localhost:8000/docs  
- **Résumé des routes** : http://localhost:8000/

---

## Liste des Endpoints

### 📀 Deezer (Recherche & Métadonnées)

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/search?q=...&type=track\|album` | Recherche Deezer (titres ou albums) |
| GET | `/api/track/{id}/meta` | Métadonnées d’un morceau (sans téléchargement) |
| GET | `/api/album/{id}/meta` | Métadonnées d’un album |
| GET | `/api/album/{id}/tracks` | Liste des pistes formatées d'un album |
| GET | `/api/playlist/{id}/meta` | Métadonnées d’une playlist |
| GET | `/api/track/{id}/cover` | Récupère la pochette d'un morceau (image/jpeg) |
| GET | `/api/album/{id}/cover` | Récupère la pochette d'un album (image/jpeg) |
| GET | `/api/playlist/{id}/cover` | Récupère la pochette d'une playlist (image/jpeg) |

### 🎥 YouTube & ☁️ SoundCloud (Recherche)

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/search/youtube?q=...&limit=15` | Recherche de vidéos sur YouTube (via `yt-dlp`) |
| GET | `/api/search/soundcloud?q=...&limit=15` | Recherche de titres sur SoundCloud (via `yt-dlp`) |

### 📥 Téléchargements

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/download/track/{id}` | Télécharge un morceau Deezer (MP3 ou FLAC) |
| GET | `/api/download/album/{id}` | Télécharge un album Deezer complet (archive ZIP) |
| GET | `/api/download/playlist/{id}` | Télécharge une playlist Deezer (archive ZIP) |
| GET | `/api/download/youtube/{video_id}` | Télécharge le flux audio d'une vidéo YouTube (MP3) |
| GET | `/api/download/soundcloud?url=...` | Télécharge un titre SoundCloud par URL (MP3) |

> 📌 `{id}` peut être l’ID seul (ex: `823267272` pour Deezer ou `dQw4w9WgXcQ` pour YouTube) ou l’URL complète (ex: `https://www.deezer.com/track/823267272`).

---

## Formats des Réponses JSON

### Recherche Deezer (`/api/search`)
```json
{
  "query": "adele hello",
  "type": "track",
  "results": [
    {
      "id": "110190530",
      "title": "Hello",
      "artist": "Adele",
      "album": "25",
      "img_url": "https://e-cdns-images.dzcdn.net/images/cover/..."
    }
  ]
}
```

### Recherche YouTube / SoundCloud (`/api/search/youtube` ou `/api/search/soundcloud`)
```json
{
  "query": "adele hello",
  "results": [
    {
      "id": "YQHsXMglC9A",
      "id_type": "youtube",
      "title": "Adele - Hello (Official Music Video)",
      "artist": "Adele",
      "img_url": "https://i.ytimg.com/vi/YQHsXMglC9A/hqdefault.jpg",
      "url": "https://www.youtube.com/watch?v=YQHsXMglC9A",
      "duration": 367
    }
  ]
}
```

---

## Spécificités de Conception

### ⚡ Concurrence et Sémaphore
L'API REST limite les téléchargements simultanés à **3 requêtes concurrentes** par défaut (configurable via la variable d'environnement `MAX_CONCURRENT_DOWNLOADS`). Si plus de 3 téléchargements sont demandés en même temps, les requêtes suivantes attendent la libération d'un slot.

### 🧹 Nettoyage automatique et robuste
- **En cours d'exécution** : Dès qu'un téléchargement HTTP de fichier audio ou d'archive ZIP se termine (réussite ou échec/annulation), FastAPI exécute une tâche d'arrière-plan (`BackgroundTasks`) pour supprimer immédiatement les fichiers et dossiers temporaires du disque.
- **Au démarrage** : À chaque lancement du serveur API, le dossier temporaire `tmp/` est intégralement vidé pour éviter l'accumulation de fichiers orphelins en cas d'arrêt brutal du conteneur/serveur.
