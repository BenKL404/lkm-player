# API REST Telegramusic (V1)

API HTTP permettant d'utiliser la logique de recherche et de téléchargement de musique (Deezer, YouTube, SoundCloud) **depuis une application externe** (ex: Flutter, LKM Player) sans passer par le bot Telegram.

## Guide de Premier Démarrage & Prérequis

Pour lancer l'API REST (et le bot) pour la première fois, suivez ces étapes :

### 1. Prérequis Système & Dépendances Externes

- **Python 3.13+** installé sur votre machine.
- **FFmpeg** : Requis pour convertir les flux YouTube/SoundCloud et insérer les métadonnées ID3.
  - *Windows* : Un script d'installation automatisé est fourni dans le dossier `services/api/` :
    ```powershell
    # Ouvrez PowerShell en Administrateur dans le dossier services/api/ et lancez :
    .\setup_ffmpeg.ps1
    ```
  - *Linux (Ubuntu/Debian)* : `sudo apt update && sudo apt install ffmpeg`
  - *macOS* : `brew install ffmpeg`

### 2. Configuration du fichier d'environnement (`token.env`)

Copiez le fichier `token.env.example` et renommez-le en `token.env` dans le dossier `services/api/`.

Renseignez les variables nécessaires :
- **`DEEZER_TOKEN`** (Requis pour Deezer) : Le cookie ARL de votre session Deezer.
  - *Comment l'obtenir* : Connectez-vous à votre compte Deezer sur votre navigateur Web, ouvrez l'inspecteur d'éléments (F12) -> **Stockage / Application** -> **Cookies** -> `deezer.com`. Copiez la valeur du cookie nommé `arl` (longue chaîne de 192 caractères).
- **`COOKIES_PATH`** (Optionnel) : Chemin absolu vers un fichier de cookies YouTube au format Netscape (pour contourner les limitations de requêtes de YouTube).
- **`TELEGRAM_TOKEN`** (Optionnel) : Requis uniquement si vous lancez également le Bot Telegram (`main.py`).
- **`API_KEY`** (Optionnel) : Clé de sécurité pour restreindre l'accès à l'API REST.
- **`MAX_CONCURRENT_DOWNLOADS`** (Optionnel, défaut: `3`) : Limite globale de téléchargements simultanés sur le serveur.
- **`FFMPEG_LOCATION`** (Optionnel) : Si ffmpeg n'est pas dans les variables d'environnement de votre système, indiquez le chemin absolu de son répertoire `bin/`.

### 3. Installation et activation de l'Environnement Virtuel

Dans le terminal, naviguez dans le dossier `services/api/` :

```bash
# 1. Créer l'environnement virtuel (à faire une seule fois)
python -m venv venv

# 2. Activer l'environnement virtuel (à chaque nouveau terminal)
# - Windows (PowerShell) :
.\venv\Scripts\Activate.ps1
# - Windows (cmd) :
.\venv\Scripts\activate.bat
# - Linux / macOS :
source venv/bin/activate

# 3. Installer les dépendances du projet
pip install -r requirements.txt
```

### 4. Lancer l'API REST

#### Via Uvicorn (Recommandé en développement)
```bash
# Avec rechargement automatique à chaque modification de code
uvicorn api.server:app --host 0.0.0.0 --port 8000 --reload
```

#### Via scripts Windows fournis
- Lancez `.\run_api.ps1` pour démarrer le serveur API REST sur le port 8000.
- Lancez `.\run_bot.ps1` pour démarrer le bot Telegram.

- **Documentation interactive Swagger** : [http://localhost:8000/docs](http://localhost:8000/docs)
- **Résumé des routes** : [http://localhost:8000/](http://localhost:8000/)

## Sécurisation par Clé API (Optionnel)

Si vous définissez la variable `API_KEY` dans votre fichier `token.env` (ex: `API_KEY=ma_cle_secrete_123`), toutes les requêtes adressées aux routes versionnées (sous `/api/v1/*`) devront obligatoirement inclure l'en-tête HTTP suivant :
```http
X-API-Key: ma_cle_secrete_123
```
Si l'en-tête est manquant ou incorrect, l'API renverra une réponse `403 Forbidden`. Si `API_KEY` n'est pas défini, la validation est ignorée et l'API reste publique.

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

### 📻 Streaming (Lecture en Direct)

| Méthode | Route | Description |
|--------|--------|-------------|
| GET | `/api/v1/deezer/track/{id}/stream?format=MP3_128\|MP3_320\|FLAC` | Diffuse en direct le flux audio décrypté en mémoire sans écriture disque |
| GET | `/api/v1/youtube/{video_id}/stream` | Diffuse en direct le flux audio d'une vidéo YouTube via `yt-dlp` |
| GET | `/api/v1/soundcloud/stream?url=...` | Diffuse en direct le flux audio d'un morceau SoundCloud via `yt-dlp` |

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

### ⚡ Concurrence & Non-blocage
- **Limitation globale** : L'API REST limite les requêtes de téléchargement simultanées à **3 requêtes concurrentes** par défaut (configurable via `MAX_CONCURRENT_DOWNLOADS` dans `token.env`) via un sémaphore global.
- **Flux non-bloquant** : Les téléchargements lourds s'effectuent dans des threads séparés via le pool de threads interne de FastAPI (`asyncio.to_thread`), garantissant que le serveur reste 100% disponible pour répondre à d'autres requêtes (recherches, métadonnées, etc.) pendant les transferts.
- **Téléchargement d'albums et playlists** : Pour éviter d'inonder Deezer de requêtes parallèles lors de la récupération d'un album ou d'une playlist, un sémaphore interne limite à **3 pistes téléchargées simultanément** par requête.

### 🧠 Système de Cache (TTL Cache)
Pour minimiser les requêtes réseau vers les serveurs de Deezer / YouTube et accélérer la navigation dans l'application mobile, l'API intègre un système de cache temporaire en mémoire :
- **Métadonnées** : Les réponses pour les métadonnées de morceaux, albums et playlists sont mises en cache pendant **10 minutes**.
- **Images de couverture (Artwork)** : Les fichiers images binaires des pochettes d'albums et de morceaux bénéficient du cache des métadonnées sous-jacentes.
- **Résultats de recherche** : Les requêtes de recherche unifiée sont mises en cache pendant **5 minutes** (évitant les appels répétés à `yt-dlp` pour les mêmes termes).

### 🧹 Nettoyage automatique
- **En cours d'exécution** : Les fichiers temporaires (fichiers audio individuels ou archives ZIP d'albums/playlists) sont supprimés du disque via les `BackgroundTasks` de FastAPI dès que le transfert réseau HTTP avec le client mobile est finalisé.
- **Au démarrage & Cycle de vie** : Le dossier temporaire `tmp/` est vidé lors de la phase de démarrage gérée par le gestionnaire de cycle de vie moderne `lifespan` de FastAPI.
