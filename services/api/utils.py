import json
import os

LANGS_FILE = json.load(open("langs.json", encoding="utf-8"))
LANG = os.environ.get("BOT_LANG")
DOWNLOADING_USERS = []

TMP_DIR = "tmp"


if LANG is not None:
    print("Lang : " + LANG)
else:
    print("Lang : en")
    LANG = "en"


def __(s):
    return LANGS_FILE[s][LANG]


def is_downloading(user_id):
    return user_id in DOWNLOADING_USERS


def add_downloading(user_id):
    DOWNLOADING_USERS.append(user_id)


def remove_downloading(user_id):
    DOWNLOADING_USERS.remove(user_id)


_bot_download_semaphore = None

def get_bot_download_semaphore():
    global _bot_download_semaphore
    if _bot_download_semaphore is None:
        import asyncio
        max_downloads = int(os.environ.get("MAX_CONCURRENT_DOWNLOADS", "3"))
        _bot_download_semaphore = asyncio.Semaphore(max_downloads)
    return _bot_download_semaphore

