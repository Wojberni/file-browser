# File-browser

File-browser is a project for educational purposes written in Zig.
I was trying to remind myself, how trees work and file structure was a natural choice.

> Code was tested on Linux, it is NOT Windows compatible.

> TUI was developed using Kitty, due to [libvaxis](https://github.com/rockorager/libvaxis) compatibility. Some functionalities might not work as they should on other terminals.

## Basic commands

Build gui, demo or tests for file-browser using following commands.

```
zig build gui
```

![Gui](gui.gif)

```
zig build demo
```
![Demo](demo.gif)

```
zig build test
```

## Project structure

* build.zig, build.zig.zon - zig build system config
* src/ - file-browser module, all core file tree functionalities
* gui/ - gui using file-browser module and [libvaxis](https://github.com/rockorager/libvaxis)
* tests/ - tests for file-browser module
* examples/ - demo of all functions for file-browser module

```
file-browser
│   README.md
│   build.zig
│   build.zig.zon
└───src
│   │   main.zig
│   │   ...
└───gui
│   │   main.zig
│   │   ...
└───tests
│   │   tests.zig
│   │   ...
└───examples
│   │   demo.zig
│   │   ...
```

## Basic flow and functionality

* tree init/deinit - file tree struct, root node from selected directory
* tree loading - loading files and directories as nodes to initialized tree structure
* tree traversal - traverse loaded tree, basically `tree` command functionality
* find node - find node and return path to it based on given name
* insert node - insert node to given path (creates files on disk as well!)
* delete node - deletes node of given path (deletes files on disk as well!)
