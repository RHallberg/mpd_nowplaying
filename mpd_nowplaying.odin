package mpd_nowplaying

import "core:fmt"
import "core:time"
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

Image_Status :: enum {
    NONE,
    PENDING,
    READY
}

Song_Data :: struct {
  title: string,
  artist: string,
  album: string,
  uri: string,
  generation: int,
  albumart_status: Image_Status,
  albumart: rl.Image,
}

Connection :: struct {
  host: cstring,
  port: u32,
  timeout_ms: u32
}

conn_params := Connection{"localhost", 6600, 15 * 1000}

Click_State :: struct {
  first_click: bool,
  click_time: time.Time,
  doubleclick_timeout_ms: f64
}

Click_Type :: enum {
  NONE,
  SINGLE,
  DOUBLE
}

fetch_album_art_sync :: proc(mutex: ^sync.Mutex, data: ^Song_Data) {
  conn := mpd.mpd_connection_new(
      conn_params.host,
      conn_params.port,
      conn_params.timeout_ms
  )
  if conn == nil {
      return
  }
  defer mpd.mpd_connection_free(conn)
  chunk_size : int : 8192
  offset : int = 0
  buffer: [chunk_size]u8
  img_data: [dynamic]u8
  img_status := Image_Status.PENDING

  sync.mutex_lock(mutex)
  uri := strings.clone_to_cstring(data.uri)
  defer delete(uri)
  data.albumart_status = img_status
  current_generation := data.generation
  sync.mutex_unlock(mutex)

  for {
    size := mpd.mpd_run_readpicture(conn, uri, cast(u32)offset, &buffer, cast(uint)chunk_size)
    if size == -1 {
      mpd.mpd_connection_clear_error(conn)
      img_status = Image_Status.NONE
      break
    } else if size == 0 && offset == 0 {
      img_status = Image_Status.NONE
      break
    } else if size == 0 {
      img_status = Image_Status.READY
      break
    }
    append(&img_data, ..buffer[:size])
    offset += cast(int)size
  }

  if img_status == Image_Status.NONE {
    delete(img_data)
    img_data = {}
    offset = 0
    for {
      size := mpd.mpd_run_albumart(conn, uri, cast(u32)offset, &buffer, cast(uint)chunk_size)
      if size == -1 {
        mpd.mpd_connection_clear_error(conn)
        img_status = Image_Status.NONE
        break
      } else if size == 0 && offset == 0 {
        img_status = Image_Status.NONE
        break
      } else if size == 0 {
        img_status = Image_Status.READY
        break
      }
      append(&img_data, ..buffer[:size])
      offset += cast(int)size
    }
  }

  image: rl.Image
  if img_status == .READY {
    image = rl.LoadImageFromMemory(".jpg", raw_data(img_data), i32(len(img_data)))
  }
  delete(img_data)

  sync.mutex_lock(mutex)
  defer sync.mutex_unlock(mutex)

  if data.generation != current_generation {
    rl.UnloadImage(image)
    return
  }
  rl.UnloadImage(data.albumart)
  data.albumart = image
  data.albumart_status = img_status

}

run_idle :: proc(initial_conn: ^mpd.MPD_Connection, mutex: ^sync.Mutex, data: ^Song_Data) {
  conn := initial_conn
  for {
    event := mpd.run_idle_player_or_queue(conn)
    if event == nil {
      for !refresh_connection(&conn) {}
      continue
    }
    song := mpd.mpd_run_current_song(conn)
    if song == nil {
      // Current song is empty when queue is replaced
      song = mpd.mpd_run_get_queue_song_pos(conn, 0)
      if song == nil {
        sync.mutex_lock(mutex)
        delete(data.title)
        delete(data.album)
        delete(data.artist)
        delete(data.uri)
        data.title = strings.clone("None")
        data.album = strings.clone("None")
        data.artist = strings.clone("None")
        data.uri = strings.clone("")
        data.generation += 1
        data.albumart_status = .NONE
        sync.mutex_unlock(mutex)
        continue
      }
    }
    new_uri := strings.clone_from_cstring(mpd.mpd_song_get_uri(song))
    sync.mutex_lock(mutex)
    current_uri := data.uri
    sync.mutex_unlock(mutex)
    if new_uri == "" || current_uri == new_uri {
      delete(new_uri)
      mpd.mpd_song_free(song)
      continue
    }
    artist := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0))
    album  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0))
    title  := strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0))
    mpd.mpd_song_free(song)

    sync.mutex_lock(mutex)
    delete(data.title)
    delete(data.album)
    delete(data.artist)
    delete(data.uri)
    data.title = title
    data.album = album
    data.artist = artist
    data.uri = new_uri
    data.generation += 1
    data.albumart_status = .PENDING
    sync.mutex_unlock(mutex)
  }
}

render_album_texture :: proc (texture: ^rl.Texture, window: ^Window) {
  source_rec := rl.Rectangle{
      x = 0.0,
      y = 0.0,
      width = f32(texture.width),
      height = f32(texture.height),
  }
  dest_rec := rl.Rectangle{
    x = 0, y =  0,
    width = f32(window.width),
    height = f32(window.height),
  }

  rl.DrawTexturePro(texture^, source_rec, dest_rec, rl.Vector2{0, 0}, 0, rl.WHITE)

}

refresh_connection :: proc (conn: ^^mpd.MPD_Connection) -> bool {
    new_conn := mpd.mpd_connection_new(
        conn_params.host,
        conn_params.port,
        conn_params.timeout_ms,
    )

    if new_conn == nil {
        return false
    }
    else if mpd.mpd_connection_get_error(new_conn) != .SUCCESS {
      mpd.mpd_connection_free(new_conn)
      return false
    }

    if conn^ != nil {
        mpd.mpd_connection_free(conn^)
    }

    conn^ = new_conn
    return true
}

main :: proc() {
  conn: ^mpd.MPD_Connection
  conn_success := refresh_connection(&conn)
  if !conn_success {
      return
  }
  defer mpd.mpd_connection_free(conn)

  window := Window{"mpd_nowplaying", 300, 300, 144, rl.ConfigFlags{.WINDOW_RESIZABLE}}
  click_state := Click_State{false, time.now(), 200}

  handle_click :: proc(click_state: ^Click_State) -> Click_Type {
    if !click_state.first_click && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
      click_state.first_click = true
      click_state.click_time = time.now()
    } else if click_state.first_click && time.duration_milliseconds(time.since(click_state.click_time)) > click_state.doubleclick_timeout_ms {
      click_state.first_click = false
      return Click_Type.SINGLE
    } else if click_state.first_click && rl.IsMouseButtonPressed(rl.MouseButton.LEFT) {
      click_state.first_click = false
      return Click_Type.DOUBLE
    }
    return Click_Type.NONE
  }

  rl.SetTraceLogLevel(rl.TraceLogLevel.NONE)
  rl.InitWindow(window.width, window.height, window.name)
  defer rl.CloseWindow()

  rl.SetWindowState(window.control_flags)
  rl.SetTargetFPS(window.fps)

  no_artwork_data := #load("no_artwork.jpg")
  no_artwork_image := rl.LoadImageFromMemory(".jpg", raw_data(no_artwork_data), i32(len(no_artwork_data)))
  no_artwork_texture := rl.LoadTextureFromImage(no_artwork_image)
  texture := rl.LoadTextureFromImage(no_artwork_image)
  rl.UnloadImage(no_artwork_image)
  defer rl.UnloadTexture(no_artwork_texture)

  mutex: sync.Mutex

  artist := strings.clone("None")
  album  := strings.clone("None")
  title  := strings.clone("None")
  uri    := strings.clone("")

  conn_refresh_time := time.now()
  song := mpd.mpd_run_current_song(conn)
  if song != nil {
    delete(artist)
    delete(album)
    delete(title)
    delete(uri)
    artist = strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ARTIST, 0))
    album  = strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_ALBUM, 0))
    title  = strings.clone_from_cstring(mpd.mpd_song_get_tag(song, mpd.MPD_Tag_Type.MPD_TAG_TITLE, 0))
    uri    = strings.clone_from_cstring(mpd.mpd_song_get_uri(song))
    mpd.mpd_song_free(song)
  }
  generation := 0
  image_should_render := true
  conn_refresh_interval_ms: f64 = 14000

  data := Song_Data{title, artist, album, uri, generation, Image_Status.NONE, {}}
  rl.SetWindowTitle(fmt.ctprintf("%s - %s", data.artist, data.title))

  idle_conn: ^mpd.MPD_Connection
  conn_success = refresh_connection(&idle_conn)
  if !conn_success {
      return
  }

  thread.create_and_start_with_poly_data3(idle_conn, &mutex, &data, run_idle)

  thread.create_and_start_with_poly_data2(arg1 = &mutex, arg2 = &data, fn = fetch_album_art_sync, self_cleanup = true)

  for !rl.WindowShouldClose() {

    elapsed := time.duration_milliseconds(time.since(conn_refresh_time))
    if elapsed > conn_refresh_interval_ms {
      conn_success = refresh_connection(&conn)
      if !conn_success {
        break
      }
      conn_refresh_time = time.now()
    }

    if rl.IsWindowResized() {
      window.width = rl.GetScreenWidth()
      window.height = rl.GetScreenHeight()
    }

    left_click := handle_click(&click_state)
    if rl.IsKeyPressed(rl.KeyboardKey.Q) {
      break
    }
    else if rl.IsKeyPressed(rl.KeyboardKey.P) ||
            rl.IsKeyPressed(rl.KeyboardKey.SPACE) ||
            left_click == Click_Type.SINGLE {
        mpd.toggle_play_pause(conn)
    }
    else if rl.IsKeyPressed(rl.KeyboardKey.N) ||
            left_click == Click_Type.DOUBLE {
        mpd.mpd_run_next(conn)
    }
    else if rl.IsKeyPressed(rl.KeyboardKey.B) ||
            rl.IsMouseButtonPressed(rl.MouseButton.RIGHT) {
        mpd.mpd_run_previous(conn)
    }

    sync.mutex_lock(&mutex)
    if data.generation != generation {
      title = data.title
      artist = data.artist
      album = data.album
      generation = data.generation
      rl.SetWindowTitle(fmt.ctprintf("%s - %s", data.artist, data.title))
      image_should_render = true
      thread.create_and_start_with_poly_data2(arg1 = &mutex, arg2 = &data, fn = fetch_album_art_sync, self_cleanup = true)
    }
    sync.mutex_unlock(&mutex)

    rl.BeginDrawing()
    rl.ClearBackground(rl.PINK)
    render_album_texture(&no_artwork_texture, &window)
    sync.mutex_lock(&mutex)
    albumart_status := data.albumart_status
    sync.mutex_unlock(&mutex)

    if(image_should_render && albumart_status == Image_Status.READY) {

      rl.UnloadTexture(texture)
      sync.mutex_lock(&mutex)
      texture = rl.LoadTextureFromImage(data.albumart)
      sync.mutex_unlock(&mutex)

      image_should_render = false
    }
    if albumart_status != Image_Status.NONE {
      render_album_texture(&texture, &window)
    }
    rl.EndDrawing()
  }
}
