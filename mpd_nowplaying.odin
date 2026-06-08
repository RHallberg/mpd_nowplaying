package mpd_nowplaying

import "core:fmt"
import "core:os"
import mpd "mpd"

print_song_info :: proc(song: ^mpd.MPD_Song) {

  artist := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0)
  album  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0)
  title  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0)
  uri    := mpd.mpd_song_get_uri(song)

  fmt.println(artist, album, title, "uri: ", uri)

}

Fetch_Art_Method :: enum {
    Albumart,
    Readpicture,
}
fetch_album_art :: proc(conn: ^mpd.MPD_Connection, song: ^mpd.MPD_Song, method: Fetch_Art_Method) -> (image: [dynamic]u8, ok: bool) {
  chunk_size : int : 8192
  offset : int = 0
  buffer: [chunk_size]u8
  img_data: [dynamic]u8
  uri    := mpd.mpd_song_get_uri(song)
  fetch_proc := mpd.mpd_run_albumart
  if method == .Readpicture {
    fetch_proc = mpd.mpd_run_readpicture
  }
  for {
    size := fetch_proc(conn, uri, cast(u32)offset, &buffer, cast(uint)chunk_size)
    if size == -1 {
      mpd.mpd_connection_clear_error(conn)
      ok = false
      break
    } else if size == 0 && offset == 0 {
      ok = false
      break
    } else if size == 0 {
      ok = true
      break
    }
    append(&img_data, ..buffer[:size])
    offset += cast(int)size
  }

  if ok {
    return img_data, ok
  }
  return {}, ok
}

main :: proc() {
    conn := mpd.mpd_connection_new(
        "localhost",
        6600,
        30000,
    )
    defer mpd.mpd_connection_free(conn)

    if conn == nil {
        return
    }

    if mpd.mpd_connection_get_error(conn) != .SUCCESS {
        fmt.println("Connection failed")
        return
    } else {
        fmt.println("Connection successful!")
    }

    song := mpd.mpd_run_get_queue_song_pos (conn, 0)
    defer mpd.mpd_song_free(song)
    if song == nil {
      fmt.println("Failed to get current song")
      return
    }

    print_song_info(song)

    img, ok := fetch_album_art(conn, song, .Albumart)
    if !ok {
      clear(&img)
      img, ok = fetch_album_art(conn, song, .Readpicture)
    }
    if ok {
      err := os.write_entire_file_from_bytes("cover.jpg", img[:])
      if err != nil {
        fmt.println("Failed to save file")
      }
    }
}
