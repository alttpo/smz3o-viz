ROMMapping @rom = null;

funcdef void SerializeSRAMDelegate(array<uint8> &r, uint16 start, uint16 endExclusive);

// Lookup table of ROM addresses depending on version:
abstract class ROMMapping {
  ROMMapping() {
    // loads document from `alttpo/lttp_names.bml` or returns an empty `Node@`:
    lttp_names = ScriptFiles::loadBML("lttp_names.bml");
  }

  protected string _title;
  string get_title() property {
    return _title;
  }

  void check_game() {}
  bool is_alttp() { return true; }
  bool is_smz3()  { return false;}
  bool is_sm()    { return false; }
  void register_pc_intercepts() {
    // intercept at PC=`JSR ClearOamBuffer; JSL MainRouting`:
    cpu::register_pc_interceptor(rom.fn_pre_main_loop, @on_main_alttp);
  }

  uint32 get_tilemap_lightWorldMap() property { return 0; }
  uint32 get_tilemap_darkWorldMap()  property { return 0; }
  uint32 get_palette_lightWorldMap() property { return 0; }
  uint32 get_palette_darkWorldMap()  property { return 0; }

  // entrance & exit tables:
  uint32 get_entrance_table_room()    property { return 0; }
  uint32 get_exit_table_room()        property { return 0; }
  uint32 get_exit_table_link_y()      property { return 0; }
  uint32 get_exit_table_link_x()      property { return 0; }

  uint32 get_fn_pre_main_loop() property               { return 0; }  // points to JSR ClearOamBuffer
  uint32 get_fn_patch() property                       { return 0; }  // points to JSL Module_MainRouting

  uint32 addr_main_routing = 0;
  void read_main_routing() {
    // don't overwrite our last read value to avoid reading a patched-over value:
    if (addr_main_routing != 0) return;

    // read JSL instruction's 24-bit address at the patch point from RESET vector:
    auto offs = uint32(bus::read_u16(fn_patch + 1));
    auto bank = uint32(bus::read_u8(fn_patch + 3));
    addr_main_routing = (bank << 16) | offs;

    message("main_routing = 0x" + fmtHex(addr_main_routing, 6));
  }
  uint32 get_fn_main_routing() property                { return addr_main_routing; }

  uint32 get_fn_dungeon_light_torch() property         { return 0; }
  uint32 get_fn_dungeon_light_torch_success() property { return 0; }
  uint32 get_fn_dungeon_extinguish_torch() property    { return 0; }
  uint32 get_fn_sprite_init() property                 { return 0; }

  uint32 get_fn_decomp_sword_gfx() property    { return 0; }
  uint32 get_fn_decomp_shield_gfx() property   { return 0; }
  uint32 get_fn_sword_palette() property       { return 0; }
  uint32 get_fn_shield_palette() property      { return 0; }
  uint32 get_fn_armor_glove_palette() property { return 0; }

  uint32 get_fn_overworld_finish_mirror_warp() property { return 0; }
  uint32 get_fn_sprite_load_gfx_properties() property { return 0; }

  uint32 get_fn_overworld_createpyramidhole() property { return 0; } // 0x1BC2A7
  
  BML::Node lttp_names;

  string location_name(const GameState@ player) {
    if (player.in_sm != 0) {
      return "In Metroid";
    }

    if (!player.is_in_game_module()) {
      return "Not In Game";
    }

    if (player.is_in_dungeon_location()) {
      string locKey = fmtHex(player.dungeon_room, 4);
      return lttp_names["underworld"][locKey].textOr("Unknown UW ${0}".format({locKey}));
    } else {
      string locKey = fmtHex(player.overworld_room, 4);
      return lttp_names["overworld"][locKey].textOr("Unknown OW ${0}".format({locKey}));
    }
  }
};

class USAROMMapping : ROMMapping {
  USAROMMapping() {
    _title = "USA v1." + fmtInt(bus::read_u8(0x00FFDB));
  }

  uint32 get_tilemap_lightWorldMap() property { return 0x0AC727; }
  uint32 get_tilemap_darkWorldMap()  property { return 0x0AD727; }
  uint32 get_palette_lightWorldMap() property { return 0x0ADB27; }
  uint32 get_palette_darkWorldMap()  property { return 0x0ADC27; }

  // entrance & exit tables:
  uint32 get_entrance_table_room()    property { return 0x02C813; }
  uint32 get_exit_table_room()        property { return 0x02DD8A; }
  uint32 get_exit_table_link_y()      property { return 0x02E051; }
  uint32 get_exit_table_link_x()      property { return 0x02E0EF; }

  uint32 get_fn_pre_main_loop() property               { return 0x008053; }
  uint32 get_fn_patch() property                       { return 0x008056; }
  //uint32 get_fn_main_routing() property                { return 0x0080B5; }
};

class EURROMMapping : ROMMapping {
  EURROMMapping() {
    _title = "EUR v1." + fmtInt(bus::read_u8(0x00FFDB));
  }

  uint32 get_tilemap_lightWorldMap() property { return 0x0AC727; }
  uint32 get_tilemap_darkWorldMap()  property { return 0x0AD727; }
  uint32 get_palette_lightWorldMap() property { return 0x0ADB27; }
  uint32 get_palette_darkWorldMap()  property { return 0x0ADC27; }

  // entrance & exit tables:
  uint32 get_entrance_table_room()    property { return 0x02C813; } // TODO
  uint32 get_exit_table_room()        property { return 0x02DD8A; } // TODO
  uint32 get_exit_table_link_y()      property { return 0x02E051; } // TODO
  uint32 get_exit_table_link_x()      property { return 0x02E0EF; } // TODO

  uint32 get_fn_pre_main_loop() property               { return 0x008053; } // TODO
  uint32 get_fn_patch() property                       { return 0x008056; } // TODO
};

class GER_EURROMMapping : ROMMapping {
  GER_EURROMMapping() {
    _title = "GER-EUR v1." + fmtInt(bus::read_u8(0x00FFDB));
  }

  uint32 get_tilemap_lightWorldMap() property { return 0x0AC727; }
  uint32 get_tilemap_darkWorldMap()  property { return 0x0AD727; }
  uint32 get_palette_lightWorldMap() property { return 0x0ADB27; }
  uint32 get_palette_darkWorldMap()  property { return 0x0ADC27; }

  // entrance & exit tables:
  uint32 get_entrance_table_room()    property { return 0x02C813; } // TODO
  uint32 get_exit_table_room()        property { return 0x02DD8A; } // TODO
  uint32 get_exit_table_link_y()      property { return 0x02E051; } // TODO
  uint32 get_exit_table_link_x()      property { return 0x02E0EF; } // TODO
  
  uint32 get_fn_pre_main_loop() property               { return 0x008053; } // TODO
  uint32 get_fn_patch() property                       { return 0x008056; } // TODO
  };

class JPROMMapping : ROMMapping {
  JPROMMapping() {
    _title = "JP v1." + fmtInt(bus::read_u8(0x00FFDB));
  }

  uint32 get_tilemap_lightWorldMap() property { return 0x0AC739; }
  uint32 get_tilemap_darkWorldMap()  property { return 0x0AD739; }
  uint32 get_palette_lightWorldMap() property { return 0x0ADB39; }
  uint32 get_palette_darkWorldMap()  property { return 0x0ADC39; }

  // entrance & exit tables:
  uint32 get_entrance_table_room()    property { return 0x02C577; } // 0x14577 in ROM file
  uint32 get_exit_table_room()        property { return 0x02DAEE; }
  uint32 get_exit_table_link_y()      property { return 0x02DDB5; }
  uint32 get_exit_table_link_x()      property { return 0x02DE53; }
  
   uint32 get_fn_pre_main_loop() property               { return 0x008053; }
  uint32 get_fn_patch() property                       { return 0x008056; }
  //uint32 get_fn_main_routing() property                { return 0x0080B5; }
};

class RandomizerMapping : JPROMMapping {
  protected string _seed;
  protected string _kind;

  RandomizerMapping(const string &in kind, const string &in seed) {
    _seed = seed;
    _kind = kind;
    _title = kind + " seed " + _seed;
  }
};

class MultiworldMapping : RandomizerMapping {
  MultiworldMapping(const string &in kind, const string &in seed) {
    super(kind, seed);
  }
};

class DoorRandomizerMapping : RandomizerMapping {
  DoorRandomizerMapping(const string &in kind, const string &in seed) {
    super(kind, seed);
  }
};

class SMZ3Mapping : RandomizerMapping {
  SMZ3Mapping(const string &in kind, const string &in seed) {
    super(kind, seed);
  }

  uint8 game = 0;
  void check_game() override {
    game = bus::read_u8(0xA173FE);
  }

  bool is_alttp() override { return game == 0; }
  bool is_smz3() override { return true;}

  void register_pc_intercepts() override {
    cpu::register_pc_interceptor(rom.fn_pre_main_loop, @on_main_alttp);

    // SM main is at 0x82893D (PHK; PLB)
    // SM main @loop (PHP; REP #$30) https://github.com/strager/supermetroid/blob/master/src/bank82.asm#L1066
    cpu::register_pc_interceptor(0x828948, @on_main_sm);
  }
}

class VanillaSMMappping : ROMMapping{

  VanillaSMMappping() {
    super();
  }
  
  bool is_alttp() override { return false; }
  bool is_smz3() override { return true;}
  bool is_sm()   override { return true; }

  void register_pc_intercepts() override {
    // SM main is at 0x82893D (PHK; PLB)
    // SM main @loop (PHP; REP #$30) https://github.com/strager/supermetroid/blob/master/src/bank82.asm#L1066
    cpu::register_pc_interceptor(0x828948, @on_main_sm);
  }

}

ROMMapping@ detect() {
  array<uint8> sig(21);
  bus::read_block_u8(0x00FFC0, 0, 21, sig);
  auto region  = bus::read_u8(0x00FFD9);
  auto version = bus::read_u8(0x00FFDB);
  auto title   = sig.toString(0, 21);
  message("ROM title: \"" + title.trimRight("\0") + "\"");
  if (title == "THE LEGEND OF ZELDA  ") {
    if (region == 0x01) {
      message("Recognized USA region ROM version v1." + fmtInt(version));
      return USAROMMapping();
    } else if (region == 0x02) {
      message("Recognized EUR region ROM version v1." + fmtInt(version));
      return EURROMMapping();
    } else if (region == 0x09) {
      message("Recognized GER-EUR region ROM version v1." + fmtInt(version));
      return GER_EURROMMapping();
    } else {
      message("Unrecognized ROM region but has US title; assuming USA ROM v1." + fmtInt(version));
      return USAROMMapping();
    }
  } else if (title == "ZELDANODENSETSU      ") {
    message("Recognized JP ROM version v1." + fmtInt(version));
    return JPROMMapping();
  } else if (title == "LOZ: PARALLEL WORLDS ") {
    message("Recognized Parallel Worlds ROM hack. Most functionality will not work due to the extreme customization of this hack.");
    return USAROMMapping();
  } else if (title.slice(0, 3) == "VT ") {
    // ALTTPR VT randomizer.
    auto seed = title.slice(3, 10);
    message("Recognized ALTTPR VT randomized JP ROM version. Seed: " + seed);
    return RandomizerMapping("VT", seed);
  } else if ( (title.slice(0, 2) == "BM") && (title[5] == '_') ) {
    // Berserker MultiWorld randomizer.
    //  0123456789
    // "BM250_1_1_16070690178"
    // "250" represents the __version__ string with '.'s removed.
    auto seed = title.slice(6, 13);
    auto kind = title.slice(0, 2) + " v" + title.slice(2, 3);
    message("Recognized Berserker MultiWorld " + kind + " randomized JP ROM version. Seed: " + seed);
    return MultiworldMapping(kind, seed);
  } else if ( title.slice(0, 2) == "BD" && (title[5] == '_') ) {
    // Berserker MultiWorld Door Randomizer.
    //  0123456789
    // "BD251_1_1_23654700304"
    // "251" represents the __version__ string with '.'s removed.
    auto seed = title.slice(6, 13);
    auto kind = title.slice(0, 2) + " v" + title.slice(2, 3);
    message("Recognized Berserker MultiWorld Door Randomizer " + kind + " randomized JP ROM version. Seed: " + seed);
    return DoorRandomizerMapping(kind, seed);
  } else if ( (title.slice(0, 2) == "ER") && (title[5] == '_') ) {
    // ALTTPR Entrance or Door Randomizer.
    //  0123456789
    // "ER002_1_1_164246190  "
    // "002" represents the __version__ string with '.'s removed.
    // see https://github.com/aerinon/ALttPDoorRandomizer/blob/DoorDev/Main.py#L27
    // and https://github.com/aerinon/ALttPDoorRandomizer/blob/DoorDev/Rom.py#L1316
    auto seed = title.slice(6, 13);
    string kind;
    bool isDoor = false;
    if (bus::read_u16(0x278000) != 0) {
      // door randomizer
      isDoor = true;
      kind = title.slice(0, 2) + " (door) v" + title.slice(2, 3);
    } else {
      // entrance randomizer
      kind = title.slice(0, 2) + " (entrance) v" + title.slice(2, 3);
    }
    message("Recognized " + kind + " randomized JP ROM version. Seed: " + seed);
    if (isDoor) {
      return DoorRandomizerMapping(kind, seed);
    } else {
      return RandomizerMapping(kind, seed);
    }
  } else if (title.slice(0, 3) == "ZSM") {
    // SMZ3 randomized
    auto seed = fmtInt(title.slice(9, 8).hex());
    auto kind = title.slice(0, 3) + " v" + title.slice(3, 4);
    message("Recognized " + kind + " randomized ROM version. Seed: " + seed);
    return SMZ3Mapping(kind, seed);
  } else if(title.slice(0, 13) == "Super Metroid"){
      message("recognized vanilla SM");
      return VanillaSMMappping();
  } else if(title.slice(0, 3) == "SM3"){
      message("recognized SM randomizer");
      return VanillaSMMappping();
  } else {
    switch (region) {
      case 0x00:
        message("Unrecognized ALTTP ROM title but region is JP v1." + fmtInt(version));
        return JPROMMapping();
      case 0x01:
        message("Unrecognized ALTTP ROM title but region is USA v1." + fmtInt(version));
        return USAROMMapping();
      case 0x02:
        message("Unrecognized ALTTP ROM title but region is EUR v1." + fmtInt(version));
        return EURROMMapping();
    }
    message("Unrecognized ALTTP ROM title and region! Assuming JP ROM region; version v1." + fmtInt(version));
    return JPROMMapping();
  }
}
