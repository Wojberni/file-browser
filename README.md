# File-browser

File-browser is a for educational purposes written in Zig.
I was trying to remind myself, how trees work and file structure was a natural choice, as it looks like a tree.
This projects mirrors selected directory structure in `Tree` struct, which you can later modify.

## Basic flow and functionality

* tree initialization - create tree struct, root node from selected directory
* tree loading - loading files and directories as nodes to initialized tree structure
* tree traversal - traverse loaded tree, basically `tree` command functionality
* node find - find node and return path to it based on given name
* insert node - insert node to given path (creates files on disk as well!)
* delete node - deletes node of given path (deletes files on disk as well!)
* tree deinitialization - deinitialize tree struct
