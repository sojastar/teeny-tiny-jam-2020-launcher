Credit: Kenny Game Assets (Only sound) www.kenney.nl

Replace the credits.png

Alter the metadata for whoever's hosting the launcher

JSON Format
```Json
[
    {
        "title": "Pretty Print Name",
        "png": "shots/name.png",
        "run": "name",
        "author": "Author's Name",
        "aut_link": "Link to author's itch.io page",
        "jam_url": "Link to author's jam entry page",
        "description": "Game description"
    }
]
```
Notes:
* I don't do any sorting on the Json entries, make sure they're sorted or add that in the launcher.
* About "run", if say, you're running the launcher on Linux and ``"run": "name"`, it'll actually execute the file `name-linux-amd64.bin`, I'm doing this on the assumption most people won't bother changing the executable build names, and most probably won't. It uses `name.app` for MacOS and `name-windows-amd64.exe` for Windows. Free free to change that if you want to. 
* If you don't have a png for the game, just leave the png attribute as `"shot/"`, the launcher will use the dragonruby.png instead
