package mpd

import "core:c"

foreign import libmpdclient "system:mpdclient"

MPD_Connection :: struct {}
MPD_Status :: struct {}

MPD_Error :: enum int {
    SUCCESS = 0,
}

MPD_State :: enum {
  MPD_STATE_UNKNOWN,
  MPD_STATE_STOP,
  MPD_STATE_PLAY,
  MPD_STATE_PAUSE,
};

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

MPD_Idle :: enum {
  MPD_IDLE_QUEUE = 0x4,
  MPD_IDLE_PLAYER = 0x8,
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

    mpd_run_current_song :: proc (
      conn: ^MPD_Connection
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

    mpd_run_idle_mask :: proc (
      conn: ^MPD_Connection,
      mask: MPD_Idle
    ) -> MPD_Idle ---

    mpd_run_status :: proc (
      conn: ^MPD_Connection
    ) -> ^MPD_Status ---

    mpd_status_get_state :: proc (
      status: ^MPD_Status
    ) -> MPD_State ---

    mpd_run_pause :: proc (
      conn: ^MPD_Connection,
      mode: c.bool
    ) -> c.bool ---

    mpd_run_next :: proc (
      conn: ^MPD_Connection
    ) -> c.bool ---

    mpd_run_previous :: proc (
      conn: ^MPD_Connection
    ) -> c.bool ---

    mpd_status_free :: proc (
      status: ^MPD_Status
    ) ---
}

run_idle_player_or_queue :: proc(conn: ^MPD_Connection) -> MPD_Idle {
    return mpd_run_idle_mask(conn, MPD_Idle.MPD_IDLE_QUEUE | MPD_Idle.MPD_IDLE_PLAYER)
}

toggle_play_pause :: proc(conn: ^MPD_Connection) {
  status := mpd_run_status(conn)
  defer mpd_status_free(status)
  state  := mpd_status_get_state(status)
  switch state {
  case .MPD_STATE_UNKNOWN, .MPD_STATE_STOP:
    return
  case .MPD_STATE_PAUSE:
    mpd_run_pause(conn, false)
  case .MPD_STATE_PLAY:
    mpd_run_pause(conn, true)
  }
}
