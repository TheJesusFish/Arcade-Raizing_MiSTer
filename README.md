# Arcade-Raizing MiSTer Core

This work-in-progress project consolidates the Raizing MiSTer cores into one
multi-game core.

## Supported Games

| Title                                                                                                                 | Status        |
|-----------------------------------------------------------------------------------------------------------------------|---------------|
| [**Sorcer Striker**](https://en.wikipedia.org/wiki/Sorcer_Striker)                                                    | Wired, needs hardware test |
| [**Kingdom Grandprix**](https://en.wikipedia.org/wiki/Kingdom_Grand_Prix)                                             | Wired, needs hardware test |
| [**Battle Garegga**](https://en.wikipedia.org/wiki/Battle_Garegga)                                                    | Boots         |
| [**Batrider**](https://en.wikipedia.org/wiki/Armed_Police_Batrider)                                                   | Boots         |
| [**Battle Bakraid**](https://en.wikipedia.org/wiki/Battle_Bakraid)                                                    | Shared battle path, needs build/hardware test |

## Development

This core uses MiSTer Template `sys/` and selected JT modules as upstream
drop-in sources. Raizing-specific changes should live in this repository's
owned wrapper and board glue files.

To compile this core, open `Arcade-Raizing.qpf` in Quartus and build the
`Arcade-Raizing` revision. Quartus writes generated artifacts into
`output_files` with the `Arcade-Raizing.*` basename.

The combined `raizing_game` wrapper dispatches by the selector byte prepended
to ROM index 0 in each MRA.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
