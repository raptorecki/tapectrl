# tapectrl

```
  __                               __         .__   
_/  |______  ______   ____   _____/  |________|  |  
\   __\__  \ \____ \_/ __ \_/ __ \   __\_  __ \  |  
 |  |  / __ \|  |_> >  ___/\  \___|  |  |  | \/  |__
 |__| (____  /   __/ \___  >\___  >__|  |__|  |____/
           \/|__|        \/     \/                  
```

A simple, menu-driven bash script for managing LTO tape drive operations in Linux, with a UI styled after the classic Debian installer.

## Features

- **Write To Tape**: Write a directory to tape using `tar`, buffered with `mbuffer`.
- **Rewind**: Rewind the tape to the beginning.
- **Verify Archive**: List the contents of an archive from the tape's current position.
- **Restore From Tape**: Rewind and restore an archive from tape to a specified directory.
- **Drive Clean**: Initiate the drive's cleaning cycle (requires a cleaning cartridge).
- **Erase Tape**: Completely erase the tape.
- **Drive Status**: Show the current status of the tape drive.
- **Offline Tape**: Rewind and eject the tape.
- **Tape Movement**: A sub-menu for fine-grained tape control:
  - Fast Forward to End of Data (EOD)
  - Forward/Backward Space Files
  - Absolute Space to File
- **Write End Of File**: Write a specified number of filemarks.
- **Retension Tape**: Wind the tape to the end and back to restore proper tension.
- **Info**: Display script version information.

## Requirements

This script is designed for Debian 12 but should work on most Linux systems. The following packages must be installed:

- `bash` (usually installed by default)
- `mt-st` (provides the `mt` command)
- `dialog` (for the user interface)
- `mbuffer` (for buffered writing and reading)
- `coreutils` (for `dd` and `tar`, usually installed by default)

You can typically install the required dependencies on Debian/Ubuntu with:
```shell
sudo apt-get update
sudo apt-get install mt-st dialog mbuffer
```

## Installation

1.  **Place the files**:
    -   Place the `tapectrl.sh` script in a directory that is in your system's `PATH`. A common choice is `/usr/local/bin`.
        ```shell
        sudo mv tapectrl.sh /usr/local/bin/tapectrl
        ```
    -   Place the `.dialogrc` theme file in your home directory to ensure the correct theme is always applied.
        ```shell
        mv .dialogrc ~/.dialogrc
        ```

2.  **Make the script executable**:
    ```shell
    sudo chmod +x /usr/local/bin/tapectrl
    ```

## Usage

Once installed, you can run the script from anywhere in your terminal by simply typing:

```shell
tapectrl
```

Follow the on-screen menus to perform tape operations.

## Configuration

- **Tape Device**: The tape device is set by the `TAPE_DEVICE` variable at the top of the script. The default is `/dev/nst0`. You can edit the script to change this if your device path is different.