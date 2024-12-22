// duped - efficient duplicate file finder/eliminator
//
// Copyright (c) 2015 Adrian Matoga
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

module main;

import std.algorithm;
import std.array;
import std.container.array;
import std.exception;
import std.file;
import std.getopt;
import std.path;
import std.range;
import std.stdio;

import core.stdc.stdlib : exit;

bool verbose;
string[] deleteGlobs;
bool listOther;

alias ExcludeFilter = bool delegate(DirEntry de);

ExcludeFilter[] excludeFilters;

string[ulong][ulong] findFilesOfTheSameSize(string[] dirs)
{
	string[ulong][ulong] result;

	void scan(string dir) {
		try {
			foreach (DirEntry de; dirEntries(dir, SpanMode.shallow, false)) {
				if (de.isSymlink || excludeFilters.map!(f => f(de)).any)
					continue;
				if (de.isDir) {
					if (verbose)
						writeln("scanning ", de.name);
					scan(de.name);
				} else if (de.isFile && de.size > 0) {
					result[de.size][de.statBuf.st_ino] = de.name;
				}
			}
		} catch (FileException ex) {
			writefln("Error: %s", ex.msg);
		}
	}

	foreach (dir; dirs)
		scan(dir);

	return result;
}

struct FileInfo
{
	string name;
	ubyte[] buffer;

	this(string name)
	{
		this.name = name;
	}

	bool readChunk(ulong offset, size_t size)
	{
		buffer.length = size;
		auto f = File(name, "rb");
		f.seek(offset);
		buffer = f.rawRead(buffer);
		return buffer.length > 0;
	}

	int opCmp(ref const(FileInfo) rhs)
	{
		return cmp(buffer, rhs.buffer);
	}

	bool opEquals(ref const(FileInfo) rhs)
	{
		return buffer == rhs.buffer;
	}

	string toString()
	{
		return name;
	}
}

string[][] groupIdenticalFiles(string[] names)
{
	enum maxChunkSize = 128 * 1024 * 1024; // * 1024 * 1024;

	// at the beginning, assume all identical, i.e. place them in the same group
	FileInfo[][] groups = [ names.map!(name => FileInfo(name)).array() ];
	ulong offset = 0;
	ulong chunkSize = 4096;
	for (;;)
	{
		FileInfo[][] newGroups;
		foreach (ref gr; groups)
		{
			foreach (ref fi; gr)
			{
				if (!fi.readChunk(offset, chunkSize))
					return groups.map!((arr) => arr.map!(fi => fi.name).array()).array();
			}

			// then split each group if the corresponding chunks differ,
			// and remove groups with count < 1
			FileInfo[][] splitGroups;
			foreach (ngr; gr.sort().chunkBy!"a == b"())
			{
				auto ng = ngr.array();
				if (ng.length > 1)
					splitGroups ~= ng;
			}
			newGroups ~= splitGroups;
		}
		if (newGroups.length == 0)
			return [];
		groups = newGroups;
		offset += chunkSize;
		if (chunkSize < maxChunkSize)
			chunkSize *= 2;
	}
}

alias Action = void delegate(string name, uint num, uint total);

Action action;

void printHelp(string[] args)
{
	writefln(
		"Usage:\n" ~
		"%1$s [-d|-m DEST_PATH] [-v] [-g PATTERN]... PATH...\n" ~
		"%1$s -h\n\n" ~
		"PATH... specifies directories to be searched for duplicate files.\n\n" ~
		"Options:\n" ~
		" -d            delete matching duplicates\n" ~
		" -m DEST_PATH  move matching duplicates to DEST_PATH,\n" ~
		"               preserving full path to the original file\n" ~
		" -g PATTERN    move/delete files whose full path matches PATTERN\n" ~
		" -l            list all other copies\n" ~
		" -v            be a bit more verbose\n" ~
		" -h            print this help\n" ~
		"Default action (if none of -d or -m is specified) is to just print\n" ~
		"names of matching duplicates.", args[0]);
}

void parseCommandLine(ref string[] args)
{
	bool doDelete;
	string movePath;
	bool help;

	getopt(args, "g", &deleteGlobs, "l", &listOther, "d", &doDelete, "m", &movePath, "v", &verbose, "h|help", &help);

	if (help)
	{
		printHelp(args);
		exit(0);
	}

	if (movePath)
	{
		movePath = movePath.absolutePath().buildNormalizedPath();
		action = (string name, uint num, uint total)
		{
			auto dest = buildNormalizedPath(movePath ~ "/" ~ name);
			if (exists(dest))
			{
				stderr.writeln("Can't move ", name, " to ", dest, ": file exists");
			}
			else
			{
				mkdirRecurse(dest.dirName());
				writefln("Move (%d/%d) %s -> %s", num, total, name, dest);
				rename(name, dest);
			}
		};
		excludeFilters ~= (DirEntry e)
		{
			return e.name.absolutePath().buildNormalizedPath().startsWith(movePath);
		};
	}
	if (doDelete)
	{
		enforce(!movePath, "Can't move and delete files at the same time.");
		action = (string name, uint num, uint total)
		{
			writefln("Delete (%d/%d) %s", num, total, name);
			remove(name);
		};
	}

	if (!action)
	{
		action = (string name, uint num, uint total)
		{
			writefln("Match (%d/%d) %s", num, total, name);
		};
	}
}

void clearLine(File file = stdout)
{
	file.writef("\r\x1b[2K");
}

void main(string[] args)
{
	try
	{
		parseCommandLine(args);
	}
	catch (Exception e)
	{
		stderr.writefln("%s: %s", args[0], e.msg);
		exit(2);
	}

	auto namesBySize = findFilesOfTheSameSize(args[1 .. $]);
	if (namesBySize.length == 0)
	{
		writeln("No files found.");
		return;
	}
	if (verbose)
		writeln(namesBySize.length, " different sizes");
	foreach (k; namesBySize.keys)
	{
		if (namesBySize[k].length < 2)
			namesBySize.remove(k);
	}
	if (namesBySize.length == 0)
	{
		writeln("No duplicates found.");
		return;
	}
	if (verbose)
		writeln(namesBySize.length, " different sizes with possible duplicates");

	size_t processedSizes;
	size_t deletedFiles;
	ulong deletedSize;
	bool haveAllMatch = false;
	auto sizes = namesBySize.keys.sort();
	sizes.reverse();
	foreach (size; sizes)
	{
		auto names = namesBySize[size];
		++processedSizes;
		clearLine();
		writef("Scanning... %d/%d: %d files of size %d", processedSizes, namesBySize.length, names.length, size);
		stdout.flush();

		// don't compare files if none of them matches any of the specified globs
		if (!names.values.any!(name => deleteGlobs.any!(glob => globMatch(name, glob))())())
			continue;

		string[][] groups;
		try
		{
			groups = groupIdenticalFiles(names.values);
		}
		catch (Exception e)
		{
			clearLine();
			writeln("Error: ", e.msg);
			continue;
		}

		foreach (group; groups)
		{
			Array!bool itemsToRemove;
			itemsToRemove.length = group.length;
			foreach (nameIndex, name; group)
			{
				foreach (glob; deleteGlobs)
				{
					if (globMatch(name, glob))
					{
						itemsToRemove[nameIndex] = true;
						break;
					}
				}
			}
			if (itemsToRemove[].all)
			{
				clearLine();
				writeln("Warning: All the following duplicates match the specified globs:");
				foreach (name; group)
					writeln("  ", name);
			}
			else if (itemsToRemove[].any)
			{
				uint num = 1;
				foreach (index, isToRemove; itemsToRemove[].enumerate())
				{
					if (isToRemove)
					{
						deletedSize += size;
						++deletedFiles;
						clearLine();
						action(group[index], num, cast(uint) group.length);
						++num;
					}
				}
				if (listOther)
				{
					foreach (index, isToRemove; itemsToRemove[].enumerate())
					{
						if (!isToRemove)
							writefln("  copy of (%d/%d) %s", num, group.length, group[index]);
					}
				}
			}
		}
	}
	clearLine();
	if (deletedFiles == 0)
		writeln("No matching duplicates found.");
	else
		writefln("Found %d bytes in %d matching duplicate files.", deletedSize, deletedFiles);
}
