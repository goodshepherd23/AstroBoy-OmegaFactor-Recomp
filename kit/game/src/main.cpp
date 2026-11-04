#include <cstdio>
#include <cstring>

#include "runtime.h"

namespace {

void print_usage() {
    std::printf(
        "AstroBoyRecomp [--bios <path>] [--rom <path>] [game.toml]\n"
        "The BIOS and ROM must match the SHA-1 identities in game.toml.\n");
}

}  // namespace

int main(int argc, char** argv) {
    for (int i = 1; i < argc; ++i) {
        if (std::strcmp(argv[i], "--help") == 0 ||
            std::strcmp(argv[i], "-h") == 0) {
            print_usage();
            return 0;
        }
    }

    gbarecomp::RunOptions opts;
    opts.builtin_game_name = "Astro Boy: Omega Factor";
    // US dump BTAE (GameData\1569 - Astro Boy - Omega Factor (U)(Venom).gba).
    opts.builtin_rom_sha1 = "4d652c24979dd7a08ee683b32d1d8986a5511a87";
    opts.builtin_rom_crc32 = 0xE8619031u;
    opts.launcher_region = "USA";
    opts.launcher_game_config = "game.toml";
    opts.launcher_save_path = "saves/astroboy_omega_factor_usa.sav";

    return gbarecomp::run_game(argc, argv, opts);
}
