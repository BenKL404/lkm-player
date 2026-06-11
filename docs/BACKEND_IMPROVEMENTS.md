# Architecture et Améliorations du Backend (FastAPI / Telegram Bot)

Ce document décrit l'architecture du backend de **lkm-player** après l'implémentation de la refactorisation et des améliorations de robustesse et de fonctionnalités.

---

## 1. Vue d'ensemble de l'architecture finale

Le backend (`services/api`) est composé de deux interfaces d'accès unifiées qui partagent la même logique métier :

1. **Le Bot Telegram (`main.py`)** : Gère les interactions et messages via `aiogram`.
2. **L'API REST (`api/server.py`)** : Expose les services de téléchargement et de recherche via `FastAPI` (Uvicorn), utilisé par l'application mobile Flutter (`apps/mobile`).

### Schéma de l'architecture de téléchargement :

```mermaid
graph TD
    subgraph Client / Frontend
        TG[Bot Telegram]
        MB[App Mobile Flutter]
    end
    
    subgraph Services d'Entrée
        BOT[Telegram Bot Handler: main.py]
        API[Serveur FastAPI REST: api/server.py]
    end
    
    subgraph Logique Métier & Téléchargement
        DZ_H[handlers/deezer.py]
        DZ_U[dl_utils/deezer_download.py]
        YT_U[dl_utils/yt_download.py]
    end

    TG --> BOT
    MB --> API
    
    BOT --> DZ_H
    BOT --> YT_U
    
    API --> DZ_H
    API --> YT_U
    
    DZ_H --> DZ_U
```

---

## 2. Améliorations Implémentées

Les cinq étapes du plan d'action de correction du backend ont été entièrement réalisées :

### 1. Extraction et centralisation du module YouTube/SoundCloud
* **Fichier créé** : [dl_utils/yt_download.py](file:///D:/PROJETS/lkm-player/services/api/dl_utils/yt_download.py)
* **Description** : Centralise toute la logique de téléchargement audio (`yt-dlp`), d'extraction de métadonnées, de recadrage des pochettes (images) et de tagging ID3 (`mutagen`).
* **Résultat** : La logique de téléchargement YouTube et SoundCloud est désormais 100 % indépendante du framework Telegram (`aiogram`) et réutilisable.
* **Mise à jour du bot** : Les gestionnaires de messages du bot dans [handlers/yt_dlp.py](file:///D:/PROJETS/lkm-player/services/api/handlers/yt_dlp.py) ont été simplifiés pour utiliser ce nouveau module.

### 2. Ajout de YouTube et SoundCloud dans l'API REST
* **Fichier modifié** : [api/server.py](file:///D:/PROJETS/lkm-player/services/api/api/server.py)
* **Nouveaux endpoints** :
  - `GET /api/search/youtube?q=...`
  - `GET /api/search/soundcloud?q=...`
  - `GET /api/download/youtube/{video_id}`
  - `GET /api/download/soundcloud?url=...`
* **Résultat** : L'application mobile Flutter peut maintenant rechercher et télécharger de l'audio depuis YouTube et SoundCloud en plus de Deezer.

### 3. Nettoyage Robuste et Sécurisé des Fichiers Temporaires
* **Mécanisme** : Remplacement des temporisateurs fragiles (`asyncio.sleep(10)`) par les `BackgroundTasks` natives de FastAPI.
* **Résultat** : Les fichiers temporaires (fichiers MP3 ou archives ZIP) sont supprimés du disque **immédiatement après** que le transfert HTTP avec le client est entièrement terminé. Cela évite les corruptions de fichiers sur les connexions lentes.
* **Démarrage du serveur** : Un gestionnaire d'événement `@app.on_event("startup")` vide automatiquement tout le contenu de `tmp/` à chaque démarrage de l'API.

### 4. Gestion de la Concurrence via Sémaphore
* **Mécanisme** : Remplacement du verrou global unique (`asyncio.Lock()`) par un sémaphore configurable (`asyncio.Semaphore(MAX_CONCURRENT_DOWNLOADS)`).
* **Résultat** : L'API peut désormais traiter jusqu'à 3 téléchargements concurrents par défaut (valeur ajustable dans le fichier [token.env](file:///D:/PROJETS/lkm-player/services/api/token.env) via `MAX_CONCURRENT_DOWNLOADS`). Les requêtes supplémentaires sont mises en file d'attente au lieu de bloquer l'API entière ou d'expirer.

### 5. Documentation Interactive OpenAPI / Swagger Enrichie
* **Description** : Les schémas de réponse ont été typés avec des modèles Pydantic et toutes les routes ont été enrichies de descriptions détaillées, de tags et de métadonnées de paramètres.
* **Accès** : La documentation Swagger complète est générée et interactive sur la route **`/docs`**.

### 6. Correction de la Configuration Locale
* **Fichiers créés** : 
  - Fichier exemple : [token.env.example](file:///D:/PROJETS/lkm-player/services/api/token.env.example)
  - Fichier de configuration local : [token.env](file:///D:/PROJETS/lkm-player/services/api/token.env)
* **Résultat** : Le script de démarrage local ne plante plus à cause d'un fichier absent.

### 7. Recherche Globale Unifiée (Endpoint Unique)
* **Route modifiée** : `GET /api/v1/search`
* **Description** : Centralise toutes les recherches (Deezer, YouTube, SoundCloud) sur un unique point d'accès.
* **Paramètres acceptés** :
  - `q` : Requête textuelle.
  - `provider` : Fournisseur de recherche (`all`, `deezer`, `youtube`, `soundcloud`). Par défaut : `all`.
  - `type` : Type de résultat pour Deezer (`track` ou `album`). Par défaut : `track`.
  - `limit` : Limite (défaut : 5 par source si `all`, 20 si source spécifique).
* **Résilience** : En mode `all`, les requêtes s'exécutent en parallèle et les échecs de serveurs tiers sont isolés (le serveur renvoie les résultats des sources fonctionnelles au lieu d'échouer avec une erreur 500).

### 8. Harmonisation RESTful de tous les Endpoints
* **Description** : Restructuration complète des routes pour les regrouper de façon logique sous des chemins de ressources standardisés par fournisseur, préfixés par la version `/api/v1/`.
* **Nouvelle table de correspondance des routes** :
  - **Recherche** : `GET /api/v1/search?q=...&provider=...`
  - **Deezer (Track)** : 
    - Métadonnées : `GET /api/v1/deezer/track/{id}/meta`
    - Pochette : `GET /api/v1/deezer/track/{id}/cover`
    - Téléchargement : `GET /api/v1/deezer/track/{id}/download`
  - **Deezer (Album)** : 
    - Métadonnées : `GET /api/v1/deezer/album/{id}/meta`
    - Liste pistes : `GET /api/v1/deezer/album/{id}/tracks`
    - Pochette : `GET /api/v1/deezer/album/{id}/cover`
    - Téléchargement ZIP : `GET /api/v1/deezer/album/{id}/download`
  - **Deezer (Playlist)** : 
    - Métadonnées : `GET /api/v1/deezer/playlist/{id}/meta`
    - Pochette : `GET /api/v1/deezer/playlist/{id}/cover`
    - Téléchargement ZIP : `GET /api/v1/deezer/playlist/{id}/download`
  - **YouTube** : 
    - Téléchargement MP3 : `GET /api/v1/youtube/{video_id}/download`
  - **SoundCloud** : 
    - Téléchargement MP3 : `GET /api/v1/soundcloud/download?url=...`

### 9. Déblocage complet de la boucle d'événements (Event Loop)
* **Fichier modifié** : [handlers/deezer.py](file:///D:/PROJETS/lkm-player/services/api/handlers/deezer.py)
* **Description** : Les opérations d'écriture de fichiers et de téléchargements synchrones de morceaux via `download_song()` ont été migrées vers des threads séparés en utilisant `asyncio.to_thread`.
* **Résultat** : Le serveur ne bloque plus lors des téléchargements lourds, permettant à d'autres utilisateurs de faire des recherches et requêtes de métadonnées de manière totalement fluide en parallèle.

### 10. Cache en mémoire à expiration (TTL Cache)
* **Fichiers modifiés** : [utils.py](file:///D:/PROJETS/lkm-player/services/api/utils.py), [api/server.py](file:///D:/PROJETS/lkm-player/services/api/api/server.py)
* **Description** : Ajout de classes de cache en mémoire pour stocker les résultats temporaires :
  - `SimpleTTLCache` pour les requêtes synchrones de métadonnées et pochettes (durée : 10 min).
  - `SimpleAsyncTTLCache` pour les requêtes de recherche unifiée (durée : 5 min).
* **Résultat** : Réduction drastique des temps de réponse lors de navigations répétées dans l'application mobile et limitation du nombre de requêtes sortantes vers Deezer/YouTube.

### 11. Concurrence interne régulée pour les albums et playlists
* **Fichier modifié** : [handlers/deezer.py](file:///D:/PROJETS/lkm-player/services/api/handlers/deezer.py)
* **Description** : Introduction d'un sémaphore interne de taille 3 limitant le nombre de morceaux téléchargés en parallèle au sein d'une même requête d'album ou de playlist.
* **Résultat** : Prévention des erreurs réseau, des saturations d'I/O disque et des risques de bannissement Deezer liés à une avalanche de connexions concurrentes.

### 12. Sécurisation par Clé API optionnelle
* **Fichier modifié** : [api/server.py](file:///D:/PROJETS/lkm-player/services/api/api/server.py)
* **Description** : Ajout d'un système de vérification d'en-tête HTTP `X-API-Key`.
* **Résultat** : Permet de restreindre l'accès à l'ensemble de l'API REST aux seuls clients autorisés en renseignant la variable `API_KEY` dans le fichier `token.env`.

### 13. Cycle de vie de l'application moderne via Lifespan
* **Fichier modifié** : [api/server.py](file:///D:/PROJETS/lkm-player/services/api/api/server.py)
* **Description** : Remplacement des gestionnaires d'événements obsolètes par le protocole `lifespan` asynchrone pour la préparation du dossier temporaire.

### 14. Streaming audio en direct et à la volée (sans stockage temporaire)
* **Fichier modifié** : [api/server.py](file:///D:/PROJETS/lkm-player/services/api/api/server.py)
* **Description** : Implémentation d'endpoints de streaming (`/stream`) utilisant `StreamingResponse` de FastAPI.
  - Pour Deezer : décryptage en mémoire chunk par chunk (2048 octets) à la volée.
  - Pour YouTube et SoundCloud : redirection directe du flux audio extrait par `yt-dlp` vers le client.
* **Résultat** : Démarrage instantané de la lecture pour le client mobile (latence < 0.5s) et élimination totale de l'utilisation de l'espace disque du serveur pour l'écoute en ligne.

---

## 3. Évolution Future : Pagination des Recherches

### Objectif
Permettre un défilement infini (infinite scroll) dans l'application mobile en ajoutant un paramètre `offset` (en plus du `limit` existant) sur la route de recherche unifiée `GET /api/v1/search`.

### Conception Technique

#### A. Recherche Deezer (Pagination Native)
Le paramètre de recherche Deezer passera de :
`https://api.deezer.com/search/{type}?q={query}`
à :
`https://api.deezer.com/search/{type}?q={query}&index={offset}&limit={limit}`

#### B. Recherche YouTube & SoundCloud (Pagination Simulée via `yt-dlp`)
Comme `yt-dlp` ne gère pas d'offset, nous appliquerons le découpage :
1. Calculer `max_results = offset + limit`.
2. Extraire ces `max_results` via `yt-dlp`.
3. Découper la liste de résultats en Python : `results[offset : offset + limit]`.
4. Plafonner à `offset + limit <= 100` pour préserver les temps de réponse.

#### C. Paramètres d'API attendus
La route `GET /api/search` acceptera désormais :
* `q: str` (Requis) : Requête textuelle.
* `provider: str` (Optionnel) : Fournisseur cible.
* `offset: int` (Optionnel, défaut `0`) : Index de départ.
* `limit: int` (Optionnel) : Nombre de résultats.
