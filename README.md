# plex-shows-organiser

`plex-shows-organiser` is a script designed to help you organize your Plex media library by sorting and renaming show files based on predefined rules.

## Features
Automatically organise shows in your plex library.
 - Puts loose video files into season folders, if possible
 - Renames video files and title cards according to show name, season and episode number, as far as parsing out of the filenames makes it possible. This script cannot reconstruct names/season numbers/episode numbers from gibberish.
 - Also works if you don't have title cards, but a rerun is necessary, after adding new title cards.
 - Goal is to sync the names of title card image files and episode video files, so plex can automatically detect the title cards.
 - Can handle minimal filenames like `203`, which would be interpreted as Season Two, Episode 3, get showname from Parent Directory. Also supported are `S02E03`, `S2E3` and a wide range of weird namings with points and spaces and the likes. These weird names mostly occur for title card images though.

## How to Run
1. Clone the repository:
    ```bash
    git clone https://github.com/your-username/plex-shows-organiser.git
    cd plex-shows-organiser
    ```
2. Place `organise.sh` into the root of your shows directory (or into a subdirectory if you only want to sync a single show or the likes).
3. Make `organise.sh` executable:
    ```bash
    chmod +x organise.sh
    ```
4. Run:
    ```bash
    ./organiser.sh
    ```

## Adding More File Extensions
To add more file extensions, like `.bmp`, simply add them to `IMAGE_EXTENSIONS`Array, same for video extensions, but use the array `VIDEO_EXTENSIONS`.

## Adding More Ignored Directories
Directory names in `SPECIAL_FOLDERS` get ignored by the script, meaning the included directories and their subdirectories do not get changed in any way. To add more ignored directories, simply add the names to the `SPECIAL_FOLDERS` array.

## Troubleshooting
As this was just a mostly quick and organically grown solution, the codebase isn't the most well strucutred one and bugs may and will occur. The script will never delete files that were not created by the script itself, but it may sometimes garble some names, if really weird naming formats are used.

If you want an issue fixed, feel free to either open a pull request with the fix, or open an issue and I might fix the problem in the future.

Enjoy a cleaner and more organized Plex library!


