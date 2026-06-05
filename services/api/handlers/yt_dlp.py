import asyncio
import os
import traceback
from aiogram import F, Router, types
from aiogram.types import BufferedInputFile, FSInputFile

from dl_utils.yt_download import download_yt_dlp
from utils import __, is_downloading, add_downloading, remove_downloading

youtube_router = Router()
soundcloud_router = Router()


@youtube_router.message(
    F.text.regexp(
        r"(?:http?s?:\/\/)?(?:www.)?(?:m.)?(?:music.)?youtu(?:\.?be)(?:\.com)?(?:("
        r"?:\w*.?:\/\/)?\w*.?\w*-?.?\w*\/(?:embed|e|v|watch|.*\/)?\??(?:feature=\w*\.?\w*)?&?("
        r"?:v=)?\/?)([\w\d_-]{11})(?:\S+)?"
    )
)
async def get_youtube_audio(event: types.Message):
    if not event.from_user:
        return

    print(f"Processing YouTube link from user {event.from_user.id}")
    if is_downloading(event.from_user.id) is False:
        add_downloading(event.from_user.id)
        tmp_msg = await event.answer(__("downloading"))
        song_path = None
        try:
            # Download and extract metadata using generic module
            result = await download_yt_dlp(event.text, is_soundcloud=False)
            song_path = result["song_path"]

            # Send cover
            if result["cover_data"]:
                try:
                    await event.answer_photo(
                        BufferedInputFile(result["cover_data"], filename="cover.jpg"),
                        caption=(
                            "<b>Track: {}</b>"
                            '\n{} - {}\n\n<a href="{}">' + __("track_link") + "</a>"
                        ).format(
                            result["title"],
                            result["artist"],
                            result["upload_date"],
                            result["webpage_url"],
                        ),
                        parse_mode="HTML",
                    )
                except Exception as photo_err:
                    print(f"Error sending photo: {photo_err}")
            else:
                await event.answer(
                    (
                        "<b>Track: {}</b>"
                        '\n{} - {}\n\n<a href="{}">' + __("track_link") + "</a>"
                    ).format(
                        result["title"],
                        result["artist"],
                        result["upload_date"],
                        result["webpage_url"],
                    ),
                    parse_mode="HTML",
                    disable_web_page_preview=True,
                )

            # Delete user message
            await event.delete()

            # Send audio
            thumb_for_sending = None
            if result["thumb_small_data"]:
                thumb_for_sending = BufferedInputFile(
                    result["thumb_small_data"], filename="thumb.jpg"
                )

            await event.answer_audio(
                FSInputFile(song_path),
                title=result["title"],
                performer=result["artist"],
                thumbnail=thumb_for_sending,
                disable_notification=True,
            )
        except Exception as e:
            traceback.print_exc()
            await event.answer(
                __("download_error") + f"\n<code>{e}</code>", parse_mode="HTML"
            )
        finally:
            await tmp_msg.delete()
            if song_path and os.path.exists(song_path):
                try:
                    os.remove(song_path)
                except OSError:
                    pass
            try:
                remove_downloading(event.from_user.id)
            except ValueError:
                pass
    else:
        tmp_err_msg = await event.answer(__("running_download"))
        await event.delete()
        await asyncio.sleep(2)
        await tmp_err_msg.delete()


@soundcloud_router.message(
    F.text.regexp(
        r"^(?:https?:\/\/)?(?:www\.)?soundcloud\.com\/([a-zA-Z0-9_-]+)\/([a-zA-Z0-9_-]+)\/?(?:\?.*)?$"
    )
)
async def get_soundcloud_audio(event: types.Message):
    if not event.from_user:
        return

    print(f"Processing SoundCloud link from user {event.from_user.id}")
    if is_downloading(event.from_user.id) is False:
        add_downloading(event.from_user.id)
        tmp_msg = await event.answer(__("downloading"))
        song_path = None
        try:
            # Download and extract metadata using generic module
            result = await download_yt_dlp(event.text, is_soundcloud=True)
            song_path = result["song_path"]

            # Send cover
            if result["cover_data"]:
                try:
                    await event.answer_photo(
                        BufferedInputFile(result["cover_data"], filename="cover.jpg"),
                        caption=(
                            "<b>Track: {}</b>"
                            '\nArtist: {}\n\n<a href="{}">' + __("track_link") + "</a>"
                        ).format(
                            result["title"],
                            result["artist"],
                            result["webpage_url"],
                        ),
                        parse_mode="HTML",
                    )
                except Exception as photo_err:
                    print(f"Error sending photo: {photo_err}")
            else:
                await event.answer(
                    (
                        "<b>Track: {}</b>"
                        '\nArtist: {}\n\n<a href="{}">' + __("track_link") + "</a>"
                    ).format(
                        result["title"],
                        result["artist"],
                        result["webpage_url"],
                    ),
                    parse_mode="HTML",
                    disable_web_page_preview=True,
                )

            # Delete user message
            await event.delete()

            # Send audio
            thumb_for_sending = None
            if result["thumb_small_data"]:
                thumb_for_sending = BufferedInputFile(
                    result["thumb_small_data"], filename="thumb.jpg"
                )

            await event.answer_audio(
                FSInputFile(song_path),
                title=result["title"],
                performer=result["artist"],
                thumbnail=thumb_for_sending,
                disable_notification=True,
            )
        except Exception as e:
            traceback.print_exc()
            await event.answer(
                __("download_error") + f"\n<code>{e}</code>", parse_mode="HTML"
            )
        finally:
            await tmp_msg.delete()
            if song_path and os.path.exists(song_path):
                try:
                    os.remove(song_path)
                except OSError:
                    pass
            try:
                remove_downloading(event.from_user.id)
            except ValueError:
                pass
    else:
        tmp_err_msg = await event.answer(__("running_download"))
        await event.delete()
        await asyncio.sleep(2)
        await tmp_err_msg.delete()
