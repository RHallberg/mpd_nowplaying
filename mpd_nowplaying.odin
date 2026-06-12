package mpd_nowplaying

import "core:fmt"
import "core:sync"
import mpd  "mpd"
import sdl  "vendor:sdl2"
import stbi "vendor:stb/image"

Song_Data :: struct {
  title:    string,
  artist:   string,
  album:    string,
  uri:      cstring,
  generation: int,
  albumart: [dynamic]u8,
}

Connection :: struct {
  host:       cstring,
  port:       u32,
  timeout_ms: u32,
}
conn_params := Connection{"localhost", 6600, 0}

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
  offset     : int = 0
  buffer: [chunk_size]u8
  img_data: [dynamic]u8
  uri        := mpd.mpd_song_get_uri(song)
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

run_idle :: proc(conn: ^mpd.MPD_Connection, mutex: ^sync.Mutex, data: ^Song_Data) {
  for {
    event := mpd.run_idle_player_or_queue(conn)
    if event != nil {
      // Get song data

      // Lock mutex

      // Save enum uri as tmp
      // Set song data in enum

      // Increment generation
      // Unlock mutex

      // Compare tmp with current song uri album
      // If new, run thread for fetching album art
    }
  }
}

main :: proc() {
  conn := mpd.mpd_connection_new(
    conn_params.host,
    conn_params.port,
    conn_params.timeout_ms,
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

  song := mpd.mpd_run_get_queue_song_pos(conn, 0)
  if song == nil {
    fmt.println("Failed to get current song")
    return
  }
  defer mpd.mpd_song_free(song)

  print_song_info(song)

  img, ok := fetch_album_art(conn, song, .Albumart)
  if !ok {
    clear(&img)
    img, ok = fetch_album_art(conn, song, .Readpicture)
  }

  if sdl.Init({.VIDEO}) != 0 {
    fmt.println("SDL init failed:", sdl.GetError())
    return
  }
  defer sdl.Quit()

  window := sdl.CreateWindow(
    "Now playing",
    sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED,
    500, 500,
    {.RESIZABLE},
  )
  if window == nil {
    fmt.println("Failed to create window:", sdl.GetError())
    return
  }
  defer sdl.DestroyWindow(window)

  renderer := sdl.CreateRenderer(window, -1, {.SOFTWARE})
  if renderer == nil {
    fmt.println("Failed to create renderer:", sdl.GetError())
    return
  }
  defer sdl.DestroyRenderer(renderer)

  w, h, channels: i32
  pixels := stbi.load_from_memory(raw_data(img), i32(len(img)), &w, &h, &channels, 4)
  defer stbi.image_free(pixels)
  clear(&img)

  surface := sdl.CreateRGBSurfaceWithFormatFrom(pixels, w, h, 32, w * 4, u32(sdl.PixelFormatEnum.RGBA32))
  texture  := sdl.CreateTextureFromSurface(renderer, surface)
  sdl.FreeSurface(surface)
  defer sdl.DestroyTexture(texture)

  render :: proc(renderer: ^sdl.Renderer, texture: ^sdl.Texture, window: ^sdl.Window) {
    win_w, win_h: i32
    sdl.GetWindowSize(window, &win_w, &win_h)
    dst := sdl.Rect{0, 0, win_w, win_h}
    sdl.RenderClear(renderer)
    sdl.RenderCopy(renderer, texture, nil, &dst)
    sdl.RenderPresent(renderer)
  }

  render(renderer, texture, window)

  running := true
  for running {
    event: sdl.Event
    sdl.WaitEvent(&event)
    #partial switch event.type {
    case .QUIT:
      running = false
    case .KEYDOWN:
      if event.key.keysym.sym == .q {
        running = false
      }
    case .WINDOWEVENT:
      if event.window.event == .RESIZED {
        render(renderer, texture, window)
      }
    }
  }
}
