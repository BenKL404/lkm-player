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


import time
import threading
from functools import wraps

class SimpleTTLCache:
    def __init__(self, ttl_seconds: int):
        self.ttl = ttl_seconds
        self.cache = {}
        self._lock = threading.Lock()

    def get(self, key):
        with self._lock:
            if key in self.cache:
                val, expiry = self.cache[key]
                if time.time() < expiry:
                    return val
                del self.cache[key]
            return None

    def set(self, key, value):
        with self._lock:
            self.cache[key] = (value, time.time() + self.ttl)

    def decorator(self, func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            key = (args, tuple(sorted(kwargs.items())))
            cached_val = self.get(key)
            if cached_val is not None:
                return cached_val
            result = func(*args, **kwargs)
            self.set(key, result)
            return result
        return wrapper


class SimpleAsyncTTLCache:
    def __init__(self, ttl_seconds: int):
        self.ttl = ttl_seconds
        self.cache = {}
        self._lock = None

    def _get_lock(self):
        # Lazily initialize loop-bound lock
        if self._lock is None:
            import asyncio
            self._lock = asyncio.Lock()
        return self._lock

    async def get(self, key):
        lock = self._get_lock()
        async with lock:
            if key in self.cache:
                val, expiry = self.cache[key]
                if time.time() < expiry:
                    return val
                del self.cache[key]
            return None

    async def set(self, key, value):
        lock = self._get_lock()
        async with lock:
            self.cache[key] = (value, time.time() + self.ttl)

    def decorator(self, func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            key = (args, tuple(sorted(kwargs.items())))
            cached_val = await self.get(key)
            if cached_val is not None:
                return cached_val
            result = await func(*args, **kwargs)
            await self.set(key, result)
            return result
        return wrapper



