package mpd_nowplaying

import "core:fmt"
import "core:os"
import "core:strings"
import mpd "mpd"
import rl   "vendor:raylib"
import sync "core:sync"
import thread "core:thread"

Window :: struct {
  name:          cstring,
  width:         i32,
  height:        i32,
  fps:           i32,
  control_flags: rl.ConfigFlags,
}

Song_Data :: struct {
  title: string,
  artist: string,
  album: string,
  uri: string,
  generation: int,
  albumart: [dynamic]u8,
}

Connection :: struct {
  host: cstring,
  port: u32,
  timeout_ms: u32
}
conn_params := Connection{"localhost", 6600, 0}

print_song_info :: proc(song: ^mpd.MPD_Song) {

  artist := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0)
  album  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0)
  title  := mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0)
  uri    := mpd.mpd_song_get_uri(song)

  fmt.println(artist, album, title, "uri: ", uri)
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

  if !ok {
    delete(img_data)
  }
  return img_data, ok
}

run_idle :: proc(conn: ^mpd.MPD_Connection, mutex: ^sync.Mutex, data: ^Song_Data) {
  for {
    event := mpd.run_idle_player_or_queue(conn)
    if event != nil {
      song := mpd.mpd_run_current_song(conn)
      if song == nil {
        // Current song is empty when queue is replaced
        song = mpd.mpd_run_get_queue_song_pos(conn, 0)
        if song == nil {
          continue
        }
      }
      defer mpd.mpd_song_free(song)
      new_uri    := strings.clone_from_cstring(mpd.mpd_song_get_uri(song))
      sync.mutex_lock(mutex)
      current_uri := data.uri
      sync.mutex_unlock(mutex)
      if(new_uri == "" || current_uri == new_uri) {
        continue
      }
      artist := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0))
      album  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0))
      title  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0))

      sync.mutex_lock(mutex)

      data.title = title
      data.album = album
      data.artist = artist
      data.uri = new_uri
      data.generation += 1

      sync.mutex_unlock(mutex)

      // TODO: Compare tmp with current song uri album
      // TODO: If new, run thread for fetching album art
    }
  }
}

main :: proc() {
  conn := mpd.mpd_connection_new(
      conn_params.host,
      conn_params.port,
      conn_params.timeout_ms
  )

  if conn == nil {
      return
  }
  defer mpd.mpd_connection_free(conn)


  if mpd.mpd_connection_get_error(conn) != .SUCCESS {
      fmt.println("Connection failed")
      return
  }
  song := mpd.mpd_run_current_song(conn)
  if song == nil {
    fmt.println("Failed to get current song")
    return
  }
  defer mpd.mpd_song_free(song)

  // print_song_info(song)

  img, ok := fetch_album_art(conn, song, .Albumart)
  if !ok {
    delete(img)
    img, ok = fetch_album_art(conn, song, .Readpicture)
  }
  window := Window{"mpd_nowplaying", 500, 500, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}

  rl.InitWindow(window.width, window.height, window.name)
  defer rl.CloseWindow()

  rl.SetWindowState(window.control_flags)
  rl.SetTargetFPS(window.fps)

  image := rl.LoadImageFromMemory(".jpg", raw_data(img), i32(len(img)))
  texture := rl.LoadTextureFromImage(image)
  defer rl.UnloadTexture(texture)
  delete(img)
  rl.UnloadImage(image)
  source_rec := rl.Rectangle{
      x = 0.0,
      y = 0.0,
      width = f32(texture.width),
      height = f32(texture.height),
  }

  idle_conn := mpd.mpd_connection_new(
      conn_params.host,
      conn_params.port,
      conn_params.timeout_ms
  )

  if idle_conn == nil {
      return
  }

  mutex: sync.Mutex

  artist := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0))
  album  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0))
  title  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0))
  uri    := strings.clone_from_cstring(mpd.mpd_song_get_uri(song))
  generation := 0

  data := Song_Data{title, artist, album, uri, generation, {}}
  thread.create_and_start_with_poly_data3(idle_conn, &mutex, &data, run_idle)
  defer mpd.mpd_connection_free(idle_conn)
  for !rl.WindowShouldClose() {

    if rl.IsWindowResized() {
      window.width = rl.GetScreenWidth()
      window.height = rl.GetScreenHeight()
    }
    if rl.IsKeyPressed(rl.KeyboardKey.Q) {
      break
    }

    sync.mutex_lock(&mutex)
    if data.generation != generation {
      title = data.title
      artist = data.artist
      album = data.album
      generation = data.generation
      fmt.println("New song:", data.artist, data.album, data.title)
    }
    sync.mutex_unlock(&mutex)

    dest_rec := rl.Rectangle{
      x = 0, y =  0,
      width = f32(window.width),
      height = f32(window.height),
    }

    rl.BeginDrawing()
    rl.ClearBackground(rl.PINK)
    rl.DrawTexturePro(texture, source_rec, dest_rec, rl.Vector2{0, 0}, 0, rl.WHITE)
    rl.EndDrawing()
  }
}
