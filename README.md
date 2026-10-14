# encryptmac

Password-protect a folder as an encrypted `.dmg` on macOS, in one command.

It does the same thing as **Disk Utility > File > New Image > Image from Folder**
with encryption, then checks that the image opens with your password and that
its contents match the original folder.

## Setup

```bash
chmod +x encrypt-folder.sh
```

## Usage

```bash
./encrypt-folder.sh ~/Desktop/Private                  # → ~/Desktop/Private.dmg (AES-256, read-only)
./encrypt-folder.sh -w ~/Desktop/Private               # read/write: you can add/change files later
./encrypt-folder.sh -a 128 ~/Desktop/Private           # AES-128 (faster) instead of AES-256
./encrypt-folder.sh -o ~/Documents/vault.dmg ~/Desktop/Private   # choose the output file
./encrypt-folder.sh -t ~/Desktop/Private               # after verifying, offer to move the original to the Trash
```

| Option | Meaning |
|---|---|
| `-o <file.dmg>` | Output path (default: `<folder>.dmg` next to the folder) |
| `-a 128\|256` | AES key size (default: 256) |
| `-w` | Read/write image (default: read-only, compressed) |
| `-t` | Move the original folder to the Trash after a successful check (asks first) |
| `-h` | Help |

The password is typed twice and never shown, stored, or passed on the command line.

## Opening the image later

Double-click the `.dmg`, enter the password, and a drive appears in Finder.
Eject it when you're done.

> There is no way to recover the files if you forget the password.
