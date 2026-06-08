package mpd

import "core:c"

foreign import libmpdclient "system:mpdclient"

MPD_Connection :: struct {}

MPD_Error :: enum int {
    SUCCESS = 0,
}

MPD_Tag_Type :: enum {

  MPD_TAG_ARTIST,
  MPD_TAG_ALBUM,
  MPD_TAG_ALBUM_ARTIST,
  MPD_TAG_TITLE,
  MPD_TAG_TRACK,
  MPD_TAG_NAME,
  MPD_TAG_GENRE,
  MPD_TAG_DATE,
  MPD_TAG_COMPOSER,
  MPD_TAG_PERFORMER,
  MPD_TAG_COMMENT,
  MPD_TAG_DISC,

  MPD_TAG_MUSICBRAINZ_ARTISTID,
  MPD_TAG_MUSICBRAINZ_ALBUMID,
  MPD_TAG_MUSICBRAINZ_ALBUMARTISTID,
  MPD_TAG_MUSICBRAINZ_TRACKID,
  MPD_TAG_MUSICBRAINZ_RELEASETRACKID,

  MPD_TAG_ORIGINAL_DATE,

  MPD_TAG_ARTIST_SORT,
  MPD_TAG_ALBUM_ARTIST_SORT,

  MPD_TAG_ALBUM_SORT,
  MPD_TAG_LABEL,
  MPD_TAG_MUSICBRAINZ_WORKID,

  MPD_TAG_GROUPING,
  MPD_TAG_WORK,
  MPD_TAG_CONDUCTOR,

  MPD_TAG_COMPOSER_SORT,
  MPD_TAG_ENSEMBLE,
  MPD_TAG_MOVEMENT,
  MPD_TAG_MOVEMENTNUMBER,
  MPD_TAG_LOCATION,
  MPD_TAG_MOOD,
  MPD_TAG_TITLE_SORT,
  MPD_TAG_MUSICBRAINZ_RELEASEGROUPID,
  MPD_TAG_SHOWMOVEMENT,

  MPD_TAG_COUNT,

  MPD_TAG_UNKNOWN = -1,
}

MPD_Song :: struct {}

foreign libmpdclient {
    mpd_connection_new :: proc (
        host: cstring,
        port: c.uint,
        timeout_ms: c.uint,
    ) -> ^MPD_Connection ---

    mpd_connection_get_error :: proc (
        conn: ^MPD_Connection,
    ) -> MPD_Error ---

    mpd_connection_get_error_message :: proc (
      conn: ^MPD_Connection,
    ) -> cstring ---

    mpd_connection_clear_error :: proc (
      conn: ^MPD_Connection
    ) -> c.bool ---

    mpd_connection_free :: proc(
        conn: ^MPD_Connection,
    ) ---

    mpd_song_get_tag :: proc (
      song: ^MPD_Song,
      type: MPD_Tag_Type,
      idx: c.uint
    ) -> cstring ---

    mpd_song_get_uri :: proc (
      song: ^MPD_Song
    ) -> cstring ---

    mpd_run_get_queue_song_pos :: proc (
      conn: ^MPD_Connection,
      pos: c.uint
    ) -> ^MPD_Song ---

    mpd_song_free :: proc (
      song: ^MPD_Song
    ) ---

    mpd_run_albumart :: proc (
      conn: ^MPD_Connection,
      uri: cstring,
      offset: c.uint,
      buffer: rawptr,
      buffer_size: c.size_t
    ) -> c.int ---

    mpd_run_readpicture :: proc (
      conn: ^MPD_Connection,
      uri: cstring,
      offset: c.uint,
      buffer: rawptr,
      buffer_size: c.size_t
    ) -> c.int ---
}
