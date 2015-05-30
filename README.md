# duped

**duped** is an efficient duplicate file finder and eliminator.
It first searches the specified directories for groups of files of the same size,
and then compares the files chunk by chunk to check if they are identical.
It starts with small chunks to quickly drop files that obviously differ, and increases the
chunk size later to maximize efficiency when comparing large files.

When two or more files are verified to be identical, **duped** can remove those that match the specified criteria
or move them to another location.
In the first case, you will just quickly get rid of duplicate files. In the latter case, you can first review
the moved files and delete them manually as needed.
If all files fulfill the criteria for being deleted or moved,
**duped** does not touch any of them to avoid accidental data loss.

## Usage

**duped** is a command line utility. You can display the usage instructions by typing:

    $ duped -h

To find and/or eliminate duplicate files, invoke **duped** using the following syntax:

    $ duped [-d|-m DEST_PATH] [-v] [-g PATTERN]... [-l] PATH...

`PATH` is the location where **duped** will search for files (recursively).
You can specify as many `PATH`s as you want.

`PATTERN` is a glob pattern which the full path of a found duplicate file must match in order
to be deleted or moved by **duped**. The `-g` option can be specified multiple times.
The following special characters are allowed in `PATTERN`:

* `*`	Matches 0 or more instances of any character.
* `?`	Matches exactly one instance of any character.
* `[chars]`	Matches one instance of any character that appears between the brackets.
* `[!chars]`	Matches one instance of any character that does not appear between the brackets after the exclamation mark.
* `{string1,string2,…}`	Matches either of the specified strings.

Since similar wildcards are used in most Unix shells, you would usually wrap the `PATTERN` in apostrophes to avoid
its expansion in the shell.

`-d` or `-m` specify the action which would be held on each found duplicate file.
`-d` tells **duped** to delete each file which matches any of the specified `PATTERN`s.
`-m` tells **duped** to move matching files to the specified `DEST_PATH`.
If no action is specified, matching duplicates are displayed, but they are left in their original place.
If all found duplicates match the specified `PATTERN` a warning is displayed and the files are not touched.

The `-l` options enables listing of all duplicates that do not match `PATTERN`.

The `-v` options makes **duped** display some additional informative messages.

## Examples

Find all duplicate files in your home directory:

    $ duped ~ -g '*'

Find all duplicate files in your home directory and delete those that end with `.bak` or `.backup`:

    $ duped ~ -g '*.bak` -g `*.backup` -d

Find duplicate files in directories */home/user/foo* and */home/user/bar* and move every duplicate
from */home/user/bar* to */home/user/duplicates/*:

    $ duped /home/user/foo /home/user/bar -g /home/user/bar -m /home/user/duplicates

## Installation

**duped** is written in the D programming language and distributed in the form of source code.
A `Makefile` is included which will allow you to quickly build **duped** provided that you have
a recent version of the DMD compiler and a GNU-compatible `make`.

With DMD 2.067.1 and GNU make on a Unix-like OS, it is sufficient to type the following commands
in the console:

    $ make
    # make install

## TODO

* Identify hard links to avoid comparison.
* Link duplicates (using hard or symbolic link) to the original instead of deleting or moving them.

## License

**duped** is distributed under the terms of the MIT license. The most important consequence of this is that
the author is not responsible for any losses resulting from the use of **duped**.
Please see the LICENSE file for more information.
