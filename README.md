# Arcade-Raizing MiSTer Core

This is a Codex-assisted update and refactoring of the Raizing FPGA core by Pramod Somashekar.

The codebase is largely still Pramod's, but updated to run on modern MiSTer hardware, and consolidated into a single core.

## Supported Games

| Title                                                                                                                 | Status        |
|-----------------------------------------------------------------------------------------------------------------------|---------------|
| [**Sorcer Striker**](https://en.wikipedia.org/wiki/Sorcer_Striker)                                                    | Public        |
| [**Kingdom Grandprix**](https://en.wikipedia.org/wiki/Kingdom_Grand_Prix)                                             | Public        |
| [**Battle Garegga**](https://en.wikipedia.org/wiki/Battle_Garegga)                                                    | Public        |
| [**Batrider**](https://en.wikipedia.org/wiki/Armed_Police_Batrider)                                                   | Public        |
| [**Battle Bakraid**](https://en.wikipedia.org/wiki/Battle_Bakraid)                                                    | Public        |

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
