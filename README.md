# encryptmac

Password-protect a file or folder as an encrypted `.dmg` on macOS, in one command.

It does the same thing as **Disk Utility > File > New Image > Image from Folder**
with encryption, then checks that the image opens with your password and that
its contents match the original.

---

## Step by step

### Part 1: one-time setup

1. **Open Terminal.** Press **⌘ + Space**, type `Terminal`, and press **Enter**.

2. **Download the script.**
   ```bash
   cd ~
   git clone https://github.com/l3k4e/encryptmac
   ```
   This creates an `encryptmac` folder in your home folder.

3. **Go into that folder and make the script runnable.**
   ```bash
   cd ~/encryptmac
   chmod +x encrypt-folder.sh
   ```

   > If you cloned it somewhere else, run `pwd` inside that folder to see its
   > path, and use that path instead of `~/encryptmac` from now on.

4. **(Optional) Add a shortcut** so you can run it from any folder:
   ```bash
   echo 'alias encrypt-folder="$HOME/encryptmac/encrypt-folder.sh"' >> ~/.zshrc
   source ~/.zshrc
   ```
   After this you can type `encrypt-folder` instead of `./encrypt-folder.sh`.

### Part 2: encrypt a file or folder

5. **Open Terminal and go to the script's folder.** You can skip this if you
   added the shortcut in step 4.
   ```bash
   cd ~/encryptmac
   ```

6. **Start typing the command, then add the file or folder.** You can do this
   in two ways:

   **Option A: drag and drop (easiest)**
   1. Type this, **with a space at the end**, and don't press Enter yet:
      ```
      ./encrypt-folder.sh -t 
      ```
   2. In Finder, **drag the file or folder into the Terminal window**.
      Terminal fills in its full path for you, for example:
      ```
      ./encrypt-folder.sh -t /Users/you/Desktop/taxes.pdf
      ```
   3. Press **Enter**.

   > ⚠️ Don't type `~/Desktop/` before dragging. Dragging already adds the full
   > path, so you'd get a doubled path like
   > `~/Desktop//Users/you/Desktop/taxes.pdf` and a "does not exist" error.

   **Option B: type the path**
   ```bash
   ./encrypt-folder.sh -t ~/Desktop/taxes.pdf
   ```

7. **Type a password, press Enter, then type it again and press Enter.**
   Nothing appears on screen while you type. That's normal.

8. **Wait for the check.** You should see:
   ```
   Creating read-only AES-256 image: /Users/you/Desktop/taxes.dmg
   Verifying the image opens and matches the original...
   OK: image opened with your password and all files match.
   ```

9. **Answer the Trash question.** Because you used `-t`, it asks:
   ```
   Move the original file '/Users/you/Desktop/taxes.pdf' to the Trash? [y/N]
   ```
   Type `y` and press **Enter**.

10. **Empty the Trash.** Right-click the Trash in the Dock and choose
    **Empty Trash**. Until you do, the unencrypted original is still there.

You now have `taxes.dmg`, and it's the only copy of your file. The `.dmg`
gets the name of the file or folder; a file's extension is dropped, so
`taxes.pdf` becomes `taxes.dmg`.

### Part 3: open it later

11. **Double-click the `.dmg`** (the disk-image icon 💿, not a folder 📁).
12. **Enter your password.** Leave **"Remember password in my keychain"**
    unticked, or anyone using your Mac account can open it without the password.
13. A drive with the same name appears in the Finder sidebar under
    **Locations**. Your files are inside it.
14. **Eject it when you're done.** Click ⏏ next to it in the sidebar, or drag
    it to the Trash. Once ejected, it's locked again.

> ⚠️ **There is no way to recover the files if you forget the password.**
> Keep it in a password manager.

### Keeping the script up to date

```bash
cd ~/encryptmac
git pull
```

---

## Options

| Option | Meaning |
|---|---|
| `-t` | After a successful check, move the original file or folder to the Trash (asks first) |
| `-w` | Read/write image, so you can add or change files later (default: read-only, compressed) |
| `-a 128\|256` | AES key size: `128` is faster, `256` is more secure (default: 256) |
| `-o <file.dmg>` | Choose the output file (default: `<name>.dmg` next to the original) |
| `-h` | Show help |

Examples:

```bash
./encrypt-folder.sh ~/Desktop/Private                  # folder → ~/Desktop/Private.dmg, keep the original
./encrypt-folder.sh -t ~/Desktop/taxes.pdf             # file → ~/Desktop/taxes.dmg, then offer to trash the original
./encrypt-folder.sh -w ~/Desktop/Private               # read/write image
./encrypt-folder.sh -a 128 ~/Desktop/Private           # AES-128 instead of AES-256
./encrypt-folder.sh -o ~/Documents/vault.dmg ~/Desktop/Private   # custom output name/location
```

Two files with the same name but different extensions (`photo.jpg`, `photo.png`)
would both become `photo.dmg`. The script won't overwrite; use `-o` to pick a
different name for the second one.

The password is typed twice and is never shown, stored, or passed on the command line.

---

## Troubleshooting

**"does not exist"**: check the path. If you dragged the file in, make sure
you didn't also type part of the path yourself (see step 6).

**"already exists"**: a `.dmg` with that name is already there. Delete or
rename it, or choose another name with `-o`.

**"cd: no such file or directory"**: the script is in a different folder than
`~/encryptmac`. Find it in Finder, then in Terminal type `cd ` (with a space)
and drag that folder into the window.

**"It opened without asking for a password"**
- **You opened the original, not the `.dmg`.** The original stays unencrypted
  unless you use `-t` and empty the Trash. Only the `.dmg` is protected.
- **The image is still open.** If a drive with that name is in the Finder
  sidebar, double-clicking the `.dmg` just shows it. Eject it first, or restart
  your Mac.
- **The password was saved in your Keychain.** If you ticked "Remember
  password", macOS won't ask again. Open *Keychain Access*, search for the
  `.dmg` name, and delete that entry.

To confirm a file is encrypted, run `hdiutil isencrypted yourfile.dmg`. It should print `encrypted: YES`.
