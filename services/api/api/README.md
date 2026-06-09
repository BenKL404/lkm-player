# API REST Telegramusic (V1)

API HTTP permettant d'utiliser la logique de recherche et de téléchargement de musique (Deezer, YouTube, SoundCloud) **depuis une application externe** (ex: Flutter, LKM Player) sans passer par le bot Telegram.

## Prérequis

- `DEEZER_TOKEN` : cookie ARL Deezer (requis uniquement pour Deezer, voir [Finding Your Deezer ARL Cookie](https://github.com/nathom/streamrip/wiki/Finding-Your-Deezer-ARL-Cookie))
- `COOKIES_PATH` : chemin optionnel vers un fichier `cookies.txt` pour contourner le blocage de YouTube
- Optionnel : `TELEGRAM_TOKEN` uniquement si vous lancez aussi le bot Telegram

## Démarrer l’API

Depuis la racine du projet :

```bash
# Windows (PowerShell)
python -m uvicorn api.server:app --host 0.0.0.0 --port 8000

# Linux / macOS
python -m uvicorn api.server:app --host 0.0.0.0 --port 8000
```

- **Docs interactives Swagger** : http://localhost:8000/docs  
- **Résumé des routes** : http://localhost:8000/

---

## Liste des Endpoints (V1)

### 🔍 Recherche Unifiée (Multi-Sources)

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/v1/search?q=...&provider=all\|deezer\|youtube\|soundcloud` | Recherche sur une ou toutes les sources en parallèle |

### 📀 Deezer (Métadonnées & Pochettes)

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/v1/deezer/track/{id}/meta` | Métadonnées d’un morceau |
| GET | `/api/v1/deezer/track/{id}/cover` | Pochette JPEG d'un morceau |
| GET | `/api/v1/deezer/album/{id}/meta` | Métadonnées d’un album |
| GET | `/api/v1/deezer/album/{id}/tracks` | Liste des pistes formatées d'un album |
| GET | `/api/v1/deezer/album/{id}/cover` | Pochette JPEG d'un album |
| GET | `/api/v1/deezer/playlist/{id}/meta` | Métadonnées d’une playlist |
| GET | `/api/v1/deezer/playlist/{id}/cover` | Pochette JPEG d'une playlist |

### 📥 Téléchargements

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/v1/deezer/track/{id}/download` | Télécharge un morceau Deezer (MP3 ou FLAC) |
| GET | `/api/v1/deezer/album/{id}/download` | Télécharge un album Deezer complet (archive ZIP) |
| GET | `/api/v1/deezer/playlist/{id}/download` | Télécharge une playlist Deezer (archive ZIP) |
| GET | `/api/v1/youtube/{video_id}/download` | Télécharge le flux audio d'une vidéo YouTube (MP3) |
| GET | `/api/v1/soundcloud/download?url=...` | Télécharge un titre SoundCloud par URL (MP3) |

> 📌 `{id}` peut être l’ID seul (ex: `823267272` pour Deezer ou `dQw4w9WgXcQ` pour YouTube) ou l’URL complète.

---

## Formats des Réponses JSON

### Recherche Unifiée (`/api/v1/search`)

#### Exemple 1 : Recherche globale (`provider=all` par défaut)
```json
{
  "source": "all",
  "deezer": {
    "tracks": [
      {
        "id": "110190530",
        "id_type": "track",
        "title": "Hello",
        "artist": "Adele",
        "album": "25",
        "img_url": "https://e-cdns-images.dzcdn.net/images/cover/..."
      }
    ],
    "albums": []
  },
  "youtube": [
    {
      "id": "YQHsXMglC9A",
      "id_type": "youtube",
      "title": "Adele - Hello (Official Music Video)",
      "artist": "Adele",
      "img_url": "https://i.ytimg.com/vi/YQHsXMglC9A/hqdefault.jpg",
      "url": "https://www.youtube.com/watch?v=YQHsXMglC9A",
      "duration": 367
    }
  ],
  "soundcloud": []
}
```

#### Exemple 2 : Recherche ciblée YouTube (`provider=youtube`)
```json
{
  "source": "youtube",
  "youtube": [
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
L'API REST limite les téléchargements simultanés à **3 requêtes concurrentes** par défaut (configurable via `MAX_CONCURRENT_DOWNLOADS` dans `token.env`).

### 🧹 Nettoyage automatique
- **En cours d'exécution** : Les fichiers temporaires sont effacés du disque via les `BackgroundTasks` de FastAPI dès que le transfert réseau avec le client est complété.
- **Au démarrage** : Le dossier temporaire `tmp/` est vidé au boot du serveur API.
