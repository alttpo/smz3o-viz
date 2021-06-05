
void pre_nmi() {
  //message("pre_nmi");

  // increment our own frame counter since in SMZ3 there is no single frame counter:
  local.frame = (local.frame + 1) & 0xff;

  if (!enableBgMusic) {
    disable_bg_music();
  }

  if (settings.started) {
    // Attempt to open a server socket:
    if (sock is null) {
      try {
        // open a UDP socket to receive data from:
        @address = net::resolve_udp(settings.ServerAddress, "4590");
        if (address is null) {
          message("Could not resolve network address '{0}'!".format({settings.ServerAddress}));
          @sock = null;
          return;
        }
        // open a UDP socket to receive data from:
        @sock = net::Socket(address);
        // connect to remote address so recv() and send() work:
        sock.connect(address);
      } catch {
        // Probably server IP field is invalid; prompt user again:
        settings.disconnect();
      }
    }
  }

  if (!enableRenderToExtra) {
    // restore previous VRAM tiles:
    localFrameState.restore();
  }

  // exit early if game is not ALTTP (for SMZ3):
  rom.check_game();
  if (!rom.is_alttp()) {
    return;
  }

  // fetch next frame's game state from WRAM:
  local.fetch_module();

  if (settings.started) {
    if (!local.is_it_a_bad_time()) {
      // play remote sfx:
      uint len = players.length();
      for (uint i = 0; i < len; i++) {
        auto @remote = players[i];
        if (remote is null) continue;
        if (remote is local) continue;
        if (remote.ttl <= 0) {
          remote.ttl = 0;
          continue;
        }
      }
    }
  }
}

void disable_bg_music() {
  // funny things happen when disabling music from the intro:
  auto module = bus::read_u8(0x7E0010);
  if (module < 0x06) return;

  // check what cmd is requested:
  auto cmd = bus::read_u8(0x7E012C);
  // allow nothing music:
  if (cmd == 0x20) return;
  // allow mirror warp:
  if (cmd == 0x08) return;
  // special commands to control volume:
  if (cmd >= 0xF1) return;

  // check what tune is currently playing:
  auto tune = bus::read_u8(0x7E0130);

  // allow no command:
  if (cmd == 0) {
    // fade out any currently playing music:
    if (tune != 0 && tune != 0x08 && tune < 0xF1) {
      bus::write_u8(0x7E012C, 0xF1);
      bus::write_u8(0x7E0130, 0xF1);
    }
    return;
  }

  // changing from mirror to some other tune:
  if (tune == 0x08) {
    // fade out so we can play mirror music again:
    bus::write_u8(0x7E012C, 0xF1);
    bus::write_u8(0x7E0130, 0xF1);
    return;
  }

  // clear track queue:
  //bus::write_u8(0x7E0132, 0);

  // no command:
  bus::write_u8(0x7E012C, 0);
}
