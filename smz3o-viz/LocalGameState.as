
const uint MaxPacketSize = 1452;

const uint OverworldAreaCount = 0x82;

class LocalGameState : GameState {
  array<Sprite@> sprs(0x80);

  Notify@ notify;

  uint8 state;
  uint32 last_sent = 0;

  uint16 animation_timer;

  LocalGameState() {
    @this.notify = Notify(@notificationSystem.notify);


    for (uint i = 0; i < 0x80; i++) {
      @sprs[i] = Sprite();
    }
  }

  void reset() override {
    GameState::reset();

    last_sent = 0;

    animation_timer = 0;
  }

  bool registered = false;
  void register(bool force = false) {
    if (force) {
      registered = false;
    }
    if (registered) return;
    if (rom is null) return;

    registered = true;
  }

  bool can_sample_location() const {
    switch (module) {
      // dungeon:
      case 0x07:
        // climbing/descending stairs
        if (sub_module == 0x0e) {
          // once main climb animation finishes, sample new location:
          if (sub_sub_module > 0x02) {
            return true;
          }
          // continue sampling old location:
          return false;
        }
        return true;
      case 0x09:  // overworld
        // disallow sampling during screen transition:
        if (sub_module >= 0x01 && sub_module <= 0x08) return false;
        // normal mirror is 0x23
        // mirror fail back to dark world is 0x2c
        if (sub_module == 0x23 || sub_module == 0x2c) {
          // once sub-sub module hits 3 then we are in light world
          if (sub_sub_module < 0x03) {
            return false;
          }
        }
        return true;
      case 0x0e:  // dialogs, maps etc.
        if (sub_module == 0x07) {
          // in-game mode7 map:
          return false;
        }
        return true;
      case 0x05:  // entering dungeon
      case 0x06:  // enter cave from overworld?
      case 0x0b:  // overworld master sword grove / zora waterfall
      case 0x08:  // exit cave to overworld
      case 0x0f:  // closing spotlight
      case 0x10:  // opening spotlight
      case 0x11:  // falling / fade out?
      case 0x12:  // death
      default:
        return true;
    }
    return true;
  }

  void fetch_module() {
    // 0x00 - Triforce / Zelda startup screens
    // 0x01 - File Select screen
    // 0x02 - Copy Player Mode
    // 0x03 - Erase Player Mode
    // 0x04 - Name Player Mode
    // 0x05 - Loading Game Mode
    // 0x06 - Pre Dungeon Mode
    // 0x07 - Dungeon Mode
    // 0x08 - Pre Overworld Mode
    // 0x09 - Overworld Mode
    // 0x0A - Pre Overworld Mode (special overworld)
    // 0x0B - Overworld Mode (special overworld)
    // 0x0C - ???? I think we can declare this one unused, almost with complete certainty.
    // 0x0D - Blank Screen
    // 0x0E - Text Mode/Item Screen/Map
    // 0x0F - Closing Spotlight
    // 0x10 - Opening Spotlight
    // 0x11 - Happens when you fall into a hole from the OW.
    // 0x12 - Death Mode
    // 0x13 - Boss Victory Mode (refills stats)
    // 0x14 - Attract Mode
    // 0x15 - Module for Magic Mirror
    // 0x16 - Module for refilling stats after boss.
    // 0x17 - Quitting mode (save and quit)
    // 0x18 - Ganon exits from Agahnim's body. Chase Mode.
    // 0x19 - Triforce Room scene
    // 0x1A - End sequence
    // 0x1B - Screen to select where to start from (House, sanctuary, etc.)
    module = bus::read_u8(0x7E0010);

    // when module = 0x07: dungeon
    //    sub_module = 0x00: Default behavior
    //               = 0x01: Intra-room transition
    //               = 0x02: Inter-room transition
    //               = 0x03: Perform overlay change (e.g. adding holes)
    //               = 0x04: opening key or big key door
    //               = 0x05: initializing room? / locked doors? / Trigger an animation?
    //               = 0x06: Upward floor transition
    //               = 0x07: Downward floor transition
    //               = 0x08: Walking up/down an in-room staircase
    //               = 0x09: Bombing or using dash attack to open a door.
    //               = 0x0A: Think it has to do with Agahnim's room in Ganon's Tower (before Ganon pops out) (or light level in room changing?)
    //               = 0x0B: Turn off water (used in swamp palace)
    //               = 0x0C: Turn on water submodule (used in swamp palace)
    //               = 0x0D: Watergate room filling with water submodule (no other known uses at the moment)
    //               = 0x0E: Going up or down inter-room spiral staircases (floor to floor)
    //               = 0x0F: Entering dungeon first time (or from mirror)
    //               = 0x10: Going up or down in-room staircases (clarify, how is this different from 0x08. Did I mean in-floor staircases?!
    //               = 0x11: ??? adds extra sprites on screen
    //               = 0x12: Walking up straight inter-room staircase
    //               = 0x13: Walking down straight inter-room staircase
    //               = 0x14: What Happens when Link falls into a damaging pit.
    //               = 0x15: Warping to another room.
    //               = 0x16: Orange/blue barrier state change?
    //               = 0x17: Quick little submodule that runs when you step on a switch to open trap doors?
    //               = 0x18: Used in the crystal sequence.
    //               = 0x19: Magic mirror as used in a dungeon. (Only works in palaces, specifically)
    //               = 0x1A:
    // when module = 0x09: overworld
    //    sub_module = 0x00 normal gameplay in overworld
    //               = 0x0e
    //      sub_sub_module = 0x01 in item menu
    //                     = 0x02 in dialog with NPC
    //               = 0x23 transitioning from light world to dark world or vice-versa
    // when module = 0x12: Link is dying
    //    sub_module = 0x00
    //               = 0x02 bonk
    //               = 0x03 black oval closing in
    //               = 0x04 red screen and spinning animation
    //               = 0x05 red screen and Link face down
    //               = 0x06 fade to black
    //               = 0x07 game over animation
    //               = 0x08 game over screen done
    //               = 0x09 save and continue menu
    sub_module = bus::read_u8(0x7E0011);

    // sub-sub-module goes from 01 to 0f during special animations such as link walking up/down stairs and
    // falling from ceiling and used as a counter for orange/blue barrier blocks transition going up/down
    sub_sub_module = bus::read_u8(0x7E00B0);
  }

  bool sprites_need_vram = false;

  void fetch() {
    sprites_need_vram = false;

    // player state:
    // 0x00 - ground state
    // 0x01 - falling into a hole
    // 0x02 - recoil from hitting wall / enemies
    // 0x03 - spin attacking
    // 0x04 - swimming
    // 0x05 - Turtle Rock platforms
    // 0x06 - recoil again (other movement)
    // 0x07 - Being electrocuted
    // 0x08 - using ether medallion
    // 0x09 - using bombos medallion
    // 0x0A - using quake medallion
    // 0x0B - Falling into a hold by jumping off of a ledge.
    // 0x0C - Falling to the left / right off of a ledge.
    // 0x0D - Jumping off of a ledge diagonally up and left / right.
    // 0x0E - Jumping off of a ledge diagonally down and left / right.
    // 0x0F - More jumping off of a ledge but with dashing maybe + some directions.
    // 0x10 - Same or similar to 0x0F?
    // 0x11 - Falling off a ledge
    // 0x12 - Used when coming out of a dash by pressing a direction other than the
    //        dash direction.
    // 0x13 - hookshot
    // 0x14 - magic mirror
    // 0x15 - holding up an item
    // 0x16 - asleep in his bed
    // 0x17 - permabunny
    // 0x18 - stuck under a heavy rock
    // 0x19 - Receiving Ether Medallion
    // 0x1A - Receiving Bombos Medallion
    // 0x1B - Opening Desert Palace
    // 0x1C - temporary bunny
    // 0x1D - Rolling back from Gargoyle gate or PullForRupees object
    // 0x1E - The actual spin attack motion.
    state = bus::read_u8(0x7E005D);

    // fetch various room indices and flags about where exactly Link currently is:
    in_dark_world = bus::read_u8(0x7E0FFF);
    in_dungeon = bus::read_u8(0x7E001B);
    overworld_room = bus::read_u16(0x7E008A);
    dungeon_room = bus::read_u16(0x7E00A0);

    dungeon = bus::read_u16(0x7E040C);
    dungeon_entrance = bus::read_u16(0x7E010E);

    animation_timer = bus::read_u16(0x7E0112);

    // compute aggregated location for Link into a single 24-bit number:
    last_actual_location = actual_location;
    actual_location =
      uint32(in_dark_world & 1) << 17 |
      uint32(in_dungeon & 1) << 16 |
      uint32(in_dungeon != 0 ? dungeon_room : overworld_room);

    if (is_in_overworld_module()) {
      last_overworld_x = x;
      last_overworld_y = y;
      //last_overworld_x = bus::read_u16(0x7EC14A);
      //last_overworld_y = bus::read_u16(0x7EC148);
    }

    if (is_it_a_bad_time()) {
      return;
    }

    // $7E0410 = OW screen transitioning directional
    //ow_screen_transition = bus::read_u8(0x7E0410);

    // Don't update location until screen transition is complete:
    if (can_sample_location() && !is_in_screen_transition()) {
      last_location = location;
      location = actual_location;
    }

    x = bus::read_u16(0x7E0022);
    y = bus::read_u16(0x7E0020);

    // get screen x,y offset by reading BG2 scroll registers:
    xoffs = int16(bus::read_u16(0x7E00E2)) - int16(bus::read_u16(0x7E011A));
    yoffs = int16(bus::read_u16(0x7E00E8)) - int16(bus::read_u16(0x7E011C));

    fetch_sprites();
  }

  bool is_frozen() {
    return bus::read_u8(0x7E02E4) != 0;
  }

  void fetch_sprites() {
    numsprites = 0;
    sprites.resize(0);
    if (is_it_a_bad_time()) {
      //message("clear sprites");
      return;
    }

    sprites_need_vram = true;

    // read OAM offset where link's sprites start at:
    int link_oam_start = bus::read_u16(0x7E0352) >> 2;
    //message(fmtInt(link_oam_start));

    // read in relevant sprites from OAM:
    array<uint8> oam(0x220);
    ppu::oam.read_block_u8(0, 0, 0x220, oam);

    // extract OAM sprites to class instances:
    sprites.reserve(128);
    for (int i = 0x00; i <= 0x7f; i++) {
      sprs[i].decodeOAMArray(oam, i);
    }

    // start from reserved region for Link (either at 0x64 or ):
    for (int j = 0; j < 0x0C; j++) {
      auto i = (link_oam_start + j) & 0x7F;

      auto @spr = sprs[i];
      // skip OAM sprite if not enabled:
      if (!spr.is_enabled) continue;

      //message("[" + fmtInt(spr.index) + "] " + fmtInt(spr.x) + "," + fmtInt(spr.y) + "=" + fmtInt(spr.chr));

      // append the sprite to our array:
      sprites.resize(++numsprites);
      @sprites[numsprites-1] = spr;
    }

    // don't sync OAM beyond link's body during or after GAME OVER animation after death:
    if (is_dead()) return;

    // capture effects sprites:
    for (int i = 0x00; i <= 0x7f; i++) {
      // skip already synced Link sprites:
      if ((i >= link_oam_start) && (i < link_oam_start + 0x0C)) continue;

      auto @spr = sprs[i];
      // skip OAM sprite if not enabled:
      if (!spr.is_enabled) continue;

      auto chr = spr.chr;
      if (chr >= 0x100) continue;

      if (i > 0) {
        auto @sprp1 = sprs[i-1];
        // Work around a bug with Leevers where they show up for a few frames as boomerangs:
        if (chr == 0x026 && sprp1.chr == 0x126) {
          continue;
        }
        // shadow underneath pot / bush or small stone
        if (chr == 0x6c && (sprp1.chr == 0x46 || sprp1.chr == 0x44 || sprp1.chr == 0x42)) {
          // append the sprite to our array:
          sprites.resize(++numsprites);
          @sprites[numsprites-1] = spr;
          continue;
        }
      }

      // water/sand/grass:
      if ((chr >= 0xc8 && chr <= 0xca) || (chr >= 0xd8 && chr <= 0xda)) {
        if (i > 0 && i <= 0x7D) {
          auto @sprp1 = sprs[i-1];
          auto @sprn1 = sprs[i+1];
          auto @sprn2 = sprs[i+2];
          // must be over follower to sync:
          if (
               // first water/sand/grass sprite:
               (chr == sprn1.chr && (sprn2.chr == 0x22 || sprn2.chr == 0x20))
               // second water/sand/grass sprite:
            || (chr == sprp1.chr && (sprn1.chr == 0x22 || sprn1.chr == 0x20))
          ) {
            // append the sprite to our array:
            sprites.resize(++numsprites);
            @sprites[numsprites-1] = spr;
            continue;
          }
        }

        continue;
      }

      // ether, bombos, quake:
      if (state == 0x08 || state == 0x09 || state == 0x0A) {
        if (
           (chr >= 0x40 && chr <= 0x4f)
        || (chr >= 0x60 && chr < 0x6c)
        ) {
          // append the sprite to our array:
          sprites.resize(++numsprites);
          @sprites[numsprites-1] = spr;
          continue;
        }
      }

      // hookshot:
      if (state == 0x13) {
        if (
           chr == 0x09 || chr == 0x0a || chr == 0x19
        ) {
          // append the sprite to our array:
          sprites.resize(++numsprites);
          @sprites[numsprites-1] = spr;
          continue;
        }
      }

      if (
        // sparkles around sword spin attack AND magic boomerang:
           chr == 0x80 || chr == 0x83 || chr == 0xb7
        // when boomerang hits solid tile:
        || chr == 0x81 || chr == 0x82
        // exclusively for spin attack:
        || chr == 0x8c || chr == 0x92 || chr == 0x93 || chr == 0xd6 || chr == 0xd7
        // bush leaves
        || chr == 0x59
        // cut grass
        || chr == 0xe2 || chr == 0xf2
        // pot shards or stone shards (large and small)
        || chr == 0x58 || chr == 0x48
        // boomerang
        || chr == 0x26
        // magic powder
        || chr == 0x09 || chr == 0x0a
        // magic cape
        || chr == 0x86 || chr == 0xa9 || chr == 0x9b
        // push block
        || chr == 0x0c
        // large stone
        || chr == 0x4a
        // holding pot / bush or small stone or sign
        || chr == 0x46 || chr == 0x44 || chr == 0x42
        // follower:
        || chr == 0x20 || chr == 0x22
      ) {
        // append the sprite to our array:
        sprites.resize(++numsprites);
        @sprites[numsprites-1] = spr;
        continue;
      }

      // don't sync the following sprites in ganon's room as it gets too busy:
      if (module == 0x07 && dungeon_room == 0x00) continue;

      if (
        // arrow:
           chr == 0x2a || chr == 0x2b || chr == 0x3a || chr == 0x3b
        || chr == 0x2c || chr == 0x2d || chr == 0x3c || chr == 0x3d
        // fire rod shot:
        || chr == 0x8d || chr == 0x9c || chr == 0x9d
        // fire rod shot flame up:
        || chr == 0x8e || chr == 0xa0 || chr == 0xa2 || chr == 0xa4 || chr == 0xa5
        // ice rod shot:
        || chr == 0xb6 || chr == 0xb7 || chr == 0x83 || chr == 0x80 || chr == 0xcf || chr == 0xdf
        // lantern fire:
        || chr == 0xe3 || chr == 0xf3 || chr == 0xa4 || chr == 0xa5 || chr == 0xb2 || chr == 0xb3 || chr == 0x9c
        // somaria block:
        || chr == 0xe9
        // somaria block explosion:
        || chr == 0xc4 || chr == 0xc5 || chr == 0xc6 || chr == 0xd2
        // somaria block shot:
        || chr == 0xc2 || chr == 0xc3 || chr == 0xd3 || chr == 0xd4
        // somaria shot explode:
        || chr == 0xd5 || chr == 0xd6
      ) {
        // append the sprite to our array:
        sprites.resize(++numsprites);
        @sprites[numsprites-1] = spr;
        continue;
      }
    }
  }

  void capture_sprites_vram() {
    if (!sprites_need_vram) {
      return;
    }

    for (int i = 0; i < numsprites; i++) {
      auto @spr = @sprites[i];
      capture_sprite(spr);
    }

    sprites_need_vram = false;
  }

  void capture_sprite(Sprite &sprite) {
    //message("capture_sprite " + fmtInt(sprite.index));
    // load character(s) from VRAM:
    if (sprite.size == 0) {
      // 8x8 sprite:
      //message("capture  x8 CHR=" + fmtHex(sprite.chr, 3));
      /*if (chrs[sprite.chr].length() == 0)*/ {
        chrs[sprite.chr].resize(16);
        ppu::vram.read_block(ppu::vram.chr_address(sprite.chr), 0, 16, chrs[sprite.chr]);
      }
    } else {
      // 16x16 sprite:
      //message("capture x16 CHR=" + fmtHex(sprite.chr, 3));
      /*if (chrs[sprite.chr + 0x00].length() == 0)*/ {
        chrs[sprite.chr + 0x00].resize(16);
        ppu::vram.read_block(ppu::vram.chr_address(sprite.chr + 0x00), 0, 16, chrs[sprite.chr + 0x00]);
      }
      /*if (chrs[sprite.chr + 0x01].length() == 0)*/ {
        chrs[sprite.chr + 0x01].resize(16);
        ppu::vram.read_block(ppu::vram.chr_address(sprite.chr + 0x01), 0, 16, chrs[sprite.chr + 0x01]);
      }
      /*if (chrs[sprite.chr + 0x10].length() == 0)*/ {
        chrs[sprite.chr + 0x10].resize(16);
        ppu::vram.read_block(ppu::vram.chr_address(sprite.chr + 0x10), 0, 16, chrs[sprite.chr + 0x10]);
      }
      /*if (chrs[sprite.chr + 0x11].length() == 0)*/ {
        chrs[sprite.chr + 0x11].resize(16);
        ppu::vram.read_block(ppu::vram.chr_address(sprite.chr + 0x11), 0, 16, chrs[sprite.chr + 0x11]);
      }
    }
  }

  uint8 get_area_size() property {
    if (module == 0x06 || is_in_dungeon_module()) {
      // underworld is always 64x64 tiles:
      return 0x40;
    }
    // assume overworld:
    return bus::read_u8(0x7E0712) > 0 ? 0x40 : 0x20;
  }

  void serialize_location(array<uint8> &r) {
    r.write_u8(uint8(0x01));

    r.write_u8(module);
    r.write_u8(sub_module);
    r.write_u8(sub_sub_module);

    r.write_u24(location);

    r.write_u16(x);
    r.write_u16(y);

    r.write_u16(dungeon);
    r.write_u16(dungeon_entrance);

    r.write_u16(last_overworld_x);
    r.write_u16(last_overworld_y);

    r.write_u16(xoffs);
    r.write_u16(yoffs);

    r.write_u16(player_color);

    r.write_u8(in_sm);
  }

  void serialize_sm_location(array<uint8> &r) {
    r.write_u8(uint8(0x0F));

    r.write_u8(sm_area);
    r.write_u8(sm_x);
    r.write_u8(sm_y);
    r.write_u8(sm_sub_x);
    r.write_u8(sm_sub_y);
    r.write_u8(in_sm);
    r.write_u8(sm_room_x);
    r.write_u8(sm_room_y);
    r.write_u8(sm_pose);
  }
  
  void serialize_sm_sprite(array<uint8> &r){
    r.write_u8(uint8(0x10));
    
    r.write_u16(offsm1);
    r.write_u16(offsm2);
    
    for(int i = 0; i < 0x10; i++){
      r.write_u16(sm_palette[i]);
    }
  }

  void serialize_name(array<uint8> &r) {
    r.write_u8(uint8(0x0C));

    r.write_str(namePadded);
  }


  uint send_sprites(uint p) {
    uint len = sprites.length();

    uint start = 0;
    uint end = len;

    // never send the shadow sprite or bomb sprite data (or anything for chr >= 0x80):
    array<bool> paletteSent(8);
    array<bool> chrSent(0x80);
    chrSent[0x6c] = true;
    chrSent[0x6d] = true;
    chrSent[0x6e] = true;
    chrSent[0x6f] = true;
    chrSent[0x7c] = true;
    chrSent[0x7d] = true;
    chrSent[0x7e] = true;
    chrSent[0x7f] = true;

    // send out possibly multiple packets to cover all sprites:
    while (start < end) {
      array<uint8> r = create_envelope(0x02);

      // serialize_sprites:
      if (start == 0) {
        // start of sprites:
        r.write_u8(uint8(0x03));
      } else {
        // continuation of sprites:
        r.write_u8(uint8(0x04));
        r.write_u8(uint8(start));
      }

      uint markLen = r.length();
      r.write_u8(uint8(end - start));

      uint mark = r.length();

      uint i;
      //message("build start=" + fmtInt(start));
      for (i = start; i < end; i++) {
        auto @spr = sprites[i];
        auto chr = spr.chr;
        auto index = spr.index;
        uint pal = spr.palette;
        auto b4 = spr.b4;

        // do we need to send the VRAM data?
        if ((chr < 0x80) && !chrSent[chr]) {
          index |= 0x80;
        }
        // do we need to send the palette data?
        if (!paletteSent[pal]) {
          b4 |= 0x80;
        }

        mark = r.length();
        //message("  mark=" + fmtInt(mark));

        // emit the OAM data:
        r.write_u8(index);
        r.write_u8(spr.b0);
        r.write_u8(spr.b1);
        r.write_u8(spr.b2);
        r.write_u8(spr.b3);
        r.write_u8(b4);

        // send VRAM data along:
        if ((index & 0x80) != 0) {
          r.write_arr(chrs[chr+0x00]);
          if (spr.size != 0) {
            r.write_arr(chrs[chr+0x01]);
            r.write_arr(chrs[chr+0x10]);
            r.write_arr(chrs[chr+0x11]);
          }
        }

        // include the palette for this sprite:
        if ((b4 & 0x80) != 0) {
          // sample the palette:
          uint cgaddr = (pal + 8) << 4;
          for (uint k = cgaddr; k < cgaddr + 16; k++) {
            r.write_u16(ppu::cgram[k]);
          }
        }

        // check length of packet:
        if (r.length() <= MaxPacketSize) {
          // mark data as sent:
          if ((index & 0x80) != 0) {
            chrSent[chr+0x00] = true;
            //chrs[chr+0x00].resize(0);
            if (spr.size != 0) {
              chrSent[chr+0x01] = true;
              chrSent[chr+0x10] = true;
              chrSent[chr+0x11] = true;
              //chrs[chr+0x01].resize(0);
              //chrs[chr+0x10].resize(0);
              //chrs[chr+0x11].resize(0);
            }
          }
          if ((b4 & 0x80) != 0) {
            paletteSent[pal] = true;
          }
        } else {
          // back out the last sprite:
          r.removeRange(mark, r.length() - mark);

          // continue at the last sprite in the next packet:
          //message("  scratch last mark");
          break;
        }
      }

      r[markLen] = uint8(i - start);
      start = i;

      // send this packet:
      p = send_packet(r, p);
    }

    return p;
  }

  array<uint8> @create_envelope(uint8 kind = 0x01) {
    array<uint8> @envelope = {};
    envelope.reserve(MaxPacketSize);

    // server envelope:
    {
      // header:
      envelope.write_u16(uint16(25887));
      // server protocol 2:
      envelope.write_u8(uint8(0x02));
      // group name: (20 bytes exactly)
      envelope.write_str(settings.GroupPadded);
      // message kind:
      envelope.write_u8(kind);
      // what we think our index is:
      envelope.write_u16(uint16(index));

      if (kind == 0x02) {
        // broadcast to sector:
        uint16 sector = actual_location;
        if ((sector & 0x010000) != 0) {
          // turn off light/dark world bit so that all underworld locations are equal:
          sector &= 0x01FFFF;
        }
        envelope.write_u32(sector);
      }
    }

    // script protocol:
    envelope.write_u8(uint8(script_protocol));

    // protocol starts with team number:
    envelope.write_u8(team);
    // frame number to correlate separate packets together:
    envelope.write_u8(frame);

    return envelope;
  }

  array<uint16> maxSize(5);

  uint send_packet(array<uint8> @envelope, uint p) {
    uint len = envelope.length();
    if (len > MaxPacketSize) {
      message("packet[" + fmtInt(p) + "] too big to send! " + fmtInt(len) + " > " + fmtInt(MaxPacketSize));
      return p;
    }

    // send packet to server:
    //message("sent " + fmtInt(envelope.length()) + " bytes");
    sock.send(0, len, envelope);

    // stats on max packet size per 128 frames:
    if (debugNet) {
      if (len > maxSize[p]) {
        maxSize[p] = len;
      }
      if ((frame & 0x7F) == 0) {
        message("["+fmtInt(p)+"] = " + fmtInt(maxSize[p]));
        maxSize[p] = 0;
      }
    }
    p++;

    return p;
  }

  void send() {
    uint p = 0;

    // check if we need to detect our local index:
    if (index == -1) {
      // request our index; receive() will take care of the response:
      auto @request = create_envelope(0x00);
      p = send_packet(request, p);
    }

    // rate limit outgoing packets to 60fps:
    if (timestamp_now - last_sent < 16) {
      return;
    }
    last_sent = timestamp_now;

    // send main packet:
    {
      auto @envelope = create_envelope();

      serialize_location(envelope);
      serialize_name(envelope);

      p = send_packet(envelope, p);
    }

    // send possibly multiple packets for sprites:
    p = send_sprites(p);

    if (!rom.is_alttp()) {
          auto @envelope = create_envelope();
          serialize_sm_location(envelope);
          p = send_packet(envelope, p);
        
          auto @envelope1 = create_envelope();
          serialize_sm_sprite(envelope1);
          p = send_packet(envelope1, p);
    }
  }

  array<string> received_items(0);
  array<string> received_quests(0);
  void collectNotifications(const string &in name) {
    if (name.length() == 0) return;

    if (name.length() >= 2 && name.slice(0, 2) == "Q#") {
      received_quests.insertLast(name.slice(2));
      return;
    }
    received_items.insertLast(name);
  }

  // update's link's tunic colors in his palette:
  void update_palette() {
    // make sure we're in a game module where Link is shown:
    if (module <= 0x05) return;
    if (module >= 0x14 && module <= 0x18) return;
    if (module >= 0x1B) return;

    // read OAM offset where link's sprites start at:
    uint link_oam_start = bus::read_u16(0x7E0352) >> 2;

    uint8 palette = 8;
    for (uint j = link_oam_start; j < link_oam_start + 0xC; j++) {
      auto @sprite = sprs[j];

      // looking for Link body sprites only to grab the palette number:
      if (!sprite.is_enabled) continue;
      //message("chr: " + fmtHex(sprite.chr, 3));
      if ((sprite.chr & 0x0f) >= 0x04) continue;
      if ((sprite.chr & 0xf0) >= 0x20) continue;

      palette = sprite.palette;
      //message("chr="+fmtHex(sprite.chr,3) + " pal="+fmtHex(sprite.palette,1));

      // assign light/dark palette colors:
      auto light = player_color;
      auto dark  = player_color_dark_75;
      for (uint i = 0, m = 1; i < 16; i++, m <<= 1) {
        if ((settings.SyncTunicLightColors & m) == m) {
          auto c = (128 + (palette << 4)) + i;
          auto color = ppu::cgram[c];
          if (color != light) {
            ppu::cgram[c] = light;
          }
        } else if ((settings.SyncTunicDarkColors & m) == m) {
          auto c = (128 + (palette << 4)) + i;
          auto color = ppu::cgram[c];
          if (color != dark) {
            ppu::cgram[c] = dark;
          }
        }
      }
    }
  }

  void set_in_sm(bool b) {
    in_sm = b ? 1 : 0;
  }
  
  void get_sm_coords() {
    if (sm_loading_room()) return;
    sm_area = bus::read_u8(0x7E079f);
    sm_x = bus::read_u8(0x7E0AF7);
    sm_y = bus::read_u8(0x7E0AFB);
    sm_sub_x = bus::read_u8(0x7E0AF6);
    sm_sub_y = bus::read_u8(0x7E0AFA);
    sm_room_x = bus::read_u8(0x7E07A1);
    sm_room_y = bus::read_u8(0x7E07A3);
    sm_pose = bus::read_u8(0x7E0A1C);
  }
  
  void get_sm_sprite_data(){
    offsm1 = bus::read_u16(0x7e071f);
    offsm2 = bus::read_u16(0x7e0721);
    bus::read_block_u16(0x7eC180, 0, sm_palette.length(), sm_palette);
  }
  
  bool deselect_tunic_sync_sm;
  void update_sm_palette(){
    sm_palette[1] = player_color_dark_33;
    sm_palette[2] = player_color;
    sm_palette[11] = player_color_dark_33;
    sm_palette[10] = player_color_dark_50;
  }
  
  void update_local_suit(){
    if(!rom.is_alttp()){
    if(settings.SyncTunic){
      bus::write_u16(0x7ec182, player_color_dark_33);
      bus::write_u16(0x7ec184, player_color);
      bus::write_u16(0x7ec196, player_color_dark_33);
      bus::write_u16(0x7ec194, player_color_dark_33);
     } else if(deselect_tunic_sync_sm){
      bus::write_u16(0x7e0a48, 0x06);
     }
  }
  
  deselect_tunic_sync_sm = settings.SyncTunic;
  }
};
