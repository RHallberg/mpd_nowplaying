PROGRAM := mpd_nowplaying

build:
	odin build . -build-mode:exe

install: build
	install -Dm755 $(PROGRAM) $(DESTDIR)/usr/local/bin/$(PROGRAM)

clean:
	rm -f $(PROGRAM)

.PHONY: build install clean
