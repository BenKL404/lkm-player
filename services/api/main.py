import asyncio
import locale
import logging
import os
import re
import sys
from pathlib import Path

from aiogram import F, Router, types, __version__ as aiogram_version
from aiogram.filters import Command
from aiogram.types import InlineKeyboardButton, InlineKeyboardMarkup

from bot import bot, dp
from handlers.deezer import deezer_router
from handlers.yt_dlp import youtube_router, soundcloud_router
from utils import TMP_DIR

if sys.version_info < (3, 13):
    print(
        "Python 3.13 is required, but you are using Python {}.{}".format(
            sys.version_info.major, sys.version_info.minor
        )
    )
    sys.exit(1)

# Print the version of all modules
print("Python version: ", sys.version)
print("aiogram version: ", aiogram_version)

locale.setlocale(locale.LC_TIME, "")

try:
    os.mkdir(TMP_DIR)
except FileExistsError:
    pass

try:
    os.mkdir(Path(TMP_DIR, "yt"))
except FileExistsError:
    pass

logging.basicConfig(level=logging.INFO)


@dp.message(Command(commands=["start", "help"]))
async def help_start(event: types.Message):
    bot_info = await bot.get_me()
    bot_name = bot_info.first_name
    bot_username = bot_info.username

    welcome = (
        f"👋 <b>Bienvenue sur {bot_name} !</b>\n\n"
        "Je permet de télécharger de la musique depuis <b>Deezer</b>, "
        "<b>YouTube</b> et <b>SoundCloud</b>.\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "📌 <b>Commandes</b>\n\n"
        "• <code>/start</code> — Ce message de bienvenue\n"
        "• <code>/help</code> — Aide et commandes\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🔍 <b>Mode inline</b> (dans n'importe quel chat)\n\n"
        f"Tape <code>@{bot_username}</code> puis :\n"
        "• <code>track</code> &lt;recherche&gt; — Chercher un morceau\n"
        "• <code>album</code> &lt;recherche&gt; — Chercher un album\n"
        "• <code>artist</code> &lt;recherche&gt; — Chercher un artiste\n\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🔗 <b>Ou envoie directement un lien ou une recherche</b>\n\n"
        "• Lien Deezer (titre, album, playlist)\n"
        "• Lien YouTube\n"
        "• Lien SoundCloud\n"
        "• Ou écrivez simplement un texte pour lancer une recherche !"
    )
    # Boutons : au clic, remplit la zone de saisie dans ce chat (pas de sélection de conversation)
    keyboard = InlineKeyboardMarkup(inline_keyboard=[
        [
            InlineKeyboardButton(
                text="🔍 Rechercher un morceau",
                switch_inline_query_current_chat="track ",
            ),
            InlineKeyboardButton(
                text="📀 Rechercher un album",
                switch_inline_query_current_chat="album ",
            ),
        ],
        [
            InlineKeyboardButton(
                text="▶️ Ouvrir la recherche",
                switch_inline_query_current_chat="",
            ),
        ],
    ])
    await event.answer(welcome, parse_mode="HTML", reply_markup=keyboard)


fallback_router = Router()

@fallback_router.callback_query(F.data.startswith("dl_"))
async def download_callback_handler(callback_query: types.CallbackQuery):
    await callback_query.answer("Téléchargement démarré...")
    parts = callback_query.data.split("_")
    if len(parts) < 3:
        return
    
    media_type = parts[1] # "track" or "album"
    media_id = parts[2]
    
    link = f"https://www.deezer.com/{media_type}/{media_id}"
    
    dummy_message = types.Message(
        message_id=callback_query.message.message_id,
        date=callback_query.message.date,
        chat=callback_query.message.chat,
        from_user=callback_query.from_user,
        text=link
    ).as_(bot)
    
    if media_type == "track":
        from handlers.deezer import handle_track_link
        await handle_track_link(dummy_message, real_link=link)
    elif media_type == "album":
        from handlers.deezer import handle_album_link
        await handle_album_link(dummy_message, real_link=link)


@fallback_router.message()
async def fallback_handler(event: types.Message):
    if not event.text or event.chat.type != "private":
        return

    text = event.text.strip()
    bot_info = await bot.get_me()
    bot_username = bot_info.username.lower()
    
    # Strip mentions
    clean_text = re.sub(rf'@+({bot_username}|LKPLAYERTESTBOT|LKPLAYER2)', '', text, flags=re.IGNORECASE).strip()
    
    # Parse prefixes
    search_type = None
    match_prefix = re.match(r'^(track|album|artist)\s+(.*)$', clean_text, re.IGNORECASE)
    if match_prefix:
        prefix = match_prefix.group(1).lower()
        query = match_prefix.group(2).strip()
        if prefix == "album":
            search_type = "album"
        else:
            search_type = "track"
    else:
        query = clean_text

    if not query:
        await event.answer("🔍 Veuillez entrer une recherche valide après la mention (ex: <code>davido</code>).", parse_mode="HTML")
        return

    tmp_msg = await event.answer(f"🔍 Recherche de <b>\"{query}\"</b> sur Deezer...", parse_mode="HTML")
    
    try:
        from dl_utils.deezer_download import TYPE_TRACK, TYPE_ALBUM, deezer_search
        import functools
        
        loop = asyncio.get_running_loop()
        
        if search_type == "album":
            albums = await loop.run_in_executor(None, functools.partial(deezer_search, query, TYPE_ALBUM))
            tracks = []
        elif search_type == "track":
            tracks = await loop.run_in_executor(None, functools.partial(deezer_search, query, TYPE_TRACK))
            albums = []
        else:
            # Search both in parallel
            tracks_task = loop.run_in_executor(None, functools.partial(deezer_search, query, TYPE_TRACK))
            albums_task = loop.run_in_executor(None, functools.partial(deezer_search, query, TYPE_ALBUM))
            tracks, albums = await asyncio.gather(tracks_task, albums_task)

        buttons = []
        
        if tracks:
            for t in tracks[:5]:
                label = f"🎵 {t['artist']} - {t['title']}"
                if len(label) > 40:
                    label = label[:37] + "..."
                buttons.append([InlineKeyboardButton(text=label, callback_data=f"dl_track_{t['id']}")])
                
        if albums:
            for a in albums[:5]:
                label = f"📀 [Album] {a['artist']} - {a['album']}"
                if len(label) > 40:
                    label = label[:37] + "..."
                buttons.append([InlineKeyboardButton(text=label, callback_data=f"dl_album_{a['id']}")])

        if not buttons:
            await tmp_msg.edit_text(f"❌ Aucun résultat trouvé pour <b>\"{query}\"</b>.", parse_mode="HTML")
            return

        reply_markup = InlineKeyboardMarkup(inline_keyboard=buttons)
        await tmp_msg.edit_text(
            f"🎵 Résultats de recherche pour <b>\"{query}\"</b> :\n"
            "<i>Cliquez sur un bouton ci-dessous pour lancer le téléchargement.</i>",
            parse_mode="HTML",
            reply_markup=reply_markup
        )
        
    except Exception as e:
        print(f"Error during bot chat search: {e}")
        await tmp_msg.edit_text(f"❌ Une erreur est survenue lors de la recherche : <code>{e}</code>", parse_mode="HTML")


async def main() -> None:
    dp.include_routers(youtube_router, soundcloud_router, deezer_router, fallback_router)
    await dp.start_polling(bot)


if __name__ == "__main__":
    asyncio.run(main())
