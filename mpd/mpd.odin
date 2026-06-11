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

MPD_Idle :: enum {
  /** song database has been updated */
  MPD_IDLE_DATABASE = 0x1,

  /** a stored playlist has been modified, created, deleted or
      renamed */
  MPD_IDLE_STORED_PLAYLIST = 0x2,

  /** the queue has been modified */
  MPD_IDLE_QUEUE = 0x4,

  /** deprecated, don't use */
  MPD_IDLE_PLAYLIST = MPD_IDLE_QUEUE,

  /** the player state has changed: play, stop, pause, seek, ... */
  MPD_IDLE_PLAYER = 0x8,

  /** the volume has been modified */
  MPD_IDLE_MIXER = 0x10,

  /** an audio output device has been enabled or disabled */
  MPD_IDLE_OUTPUT = 0x20,

  /** options have changed: crossfade, random, repeat, ... */
  MPD_IDLE_OPTIONS = 0x40,

  /** a database update has started or finished. */
  MPD_IDLE_UPDATE = 0x80,

  /** a sticker has been modified. */
  MPD_IDLE_STICKER = 0x100,

  /** a client has subscribed to or unsubscribed from a channel */
  MPD_IDLE_SUBSCRIPTION = 0x200,

  /** a message on a subscribed channel was received */
  MPD_IDLE_MESSAGE = 0x400,

  /** a partition was added or changed */
  MPD_IDLE_PARTITION = 0x800,

  /** a neighbor was found or lost */
  MPD_IDLE_NEIGHBOR = 0x1000,

  /** the mount list has changed */
  MPD_IDLE_MOUNT = 0x2000,
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

    mpd_run_idle_mask :: proc (
      conn: ^MPD_Connection , 
      mask: MPD_Idle
    ) -> MPD_Idle ---
}

run_idle_player_or_queue :: proc(conn: ^MPD_Connection) -> MPD_Idle {
    return mpd_run_idle_mask(conn, MPD_Idle.MPD_IDLE_QUEUE | MPD_Idle.MPD_IDLE_PLAYER)
}
