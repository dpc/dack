/*
 * Copyright (C) 2007 Dawid Ciężarkiewicz
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.

 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.

 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
 * 02110-1301, USA.
 */

module dack;

import
	tango.core.Exception,
	tango.io.FileScan,
	tango.io.Stdout,
	tango.io.stream.FileStream,
	tango.io.stream.LineStream,
	tango.text.Regex,
	tango.text.stream.LineIterator,
	tango.util.ArgParser
	;

/**
 * Main class.
 *
 * DAck class takes care of processing
 * all paths and looking for matches.
 */
class DAck {
private:
	/**
	 * Regex we are looking for in files.
	 */
	Regex regex;

	/**
	 * Format used to output
	 * a match.
	 */
	char[] matchFormat;

	/**
	 * Dir names that should be ignored.
	 */
	char[][] ignoredDirNames = [".svn", ".git"];

	/**
	 * Names of files that should be ignored.
	 */
	char[][] ignoredFileNames = [];

	/**
	 * Extensions of files that should be ignored.
	 */
	char[][] ignoredFileExts = ["o", "a", "swp"];

protected:
	// some options
	/**
	 * True if output delimiter should be '\0' instead of '\n'.
	 */
	bool usePrint0;
	/**
	 * True if only first match in file should be printed.
	 */
	bool printOneTimeOnly;
	/**
	 * True if file names should be printed.
	 */
	bool printNames;
	/**
	 * True if match line should be printed.
	 */
	bool printLinesNumbers;
	/**
	 * True if content of matching line should be printed.
	 */
	bool printWholeLines;
	/**
	 * Root paths of processing.
	 */
	FilePath[] rootPaths;


public:
	/**
	 * Just a Ctor.
	 */
	this() {
		printNames = true;
		printLinesNumbers = true;
		printWholeLines = false;
	}

	/**
	 * Start processing rootPaths.
	 */
	void start() {

		if (regex is null) {
			regex = Regex(".*");
			printOneTimeOnly = true;
			printLinesNumbers = false;
		}

		if (printNames) {
			matchFormat ~= "{0}";
		}

		if (printNames && printLinesNumbers) {
			matchFormat ~= ":";
		}

		if (printLinesNumbers) {
			matchFormat ~= "{1}";
		}

		if (printWholeLines) {
			matchFormat ~= " {2}";
		}

		if (usePrint0) {
			matchFormat ~= "\0";
		} else {
			matchFormat ~= "\n";
		}

		foreach(path; rootPaths) {
			processPath(path);
		}
	}

	/**
	 * Decide if dir content should be processed
	 * or it should be skipped.
	 *
	 * Returns:
	 * false = dir should be skipped
	 * true  = dir should be processed
	 */
	bool shouldProcessDir(FilePath path) {
		auto name = path.name();

		foreach(iname; ignoredDirNames) {
			if (name == iname) {
				return false;
			}
		}

		return true;
	}

	/**
	 * Process dir.
	 */
	void processDir(FilePath path) {
		foreach (entry; path.toList) {
			processPath(entry);
		}
	}

	/**
	 * Decide if file content should be processed
	 * or it should be skipped.
	 *
	 * Returns:
	 * false = file should be skipped
	 * true  = file should be processed
	 */
	bool shouldProcessFile(FilePath path) {
		auto ext = path.ext();
		auto name = path.name();

		foreach(iext; ignoredFileExts) {
			if (ext == iext) {
				return false;
			}
		}
		foreach(iname; ignoredFileNames) {
			if (name == iname) {
				return false;
			}
		}

		return true;
	}

	/**
	 * Process file.
	 */
	void processFile(FilePath path) {
		auto line_num = 0;
		try {
			auto input = new LineInput (new FileInput(path.toString()));
			scope(exit) { input.close; }
			foreach (line; input) {
				if (regex.test(line)) {
					printMatch(path, line_num, line);
					if (printOneTimeOnly) {
						return;
					}
				}
				++line_num;
			}
		} catch (IOException e) {
			Stderr.format ("{}:{} - ERROR: {}\n",
				path.toString(), line_num,
				e.toString()
				);
		}
	}

	/**
	 * Decide if given path should be processed.
	 *
	 * Returns:
	 * false = path should be skipped
	 * true  = path should be processed
	 */
	void processPath(FilePath path) {
		if (path.isFolder()) {
			if (shouldProcessDir(path)) {
				processDir(path);
			}
		} else {
			if (shouldProcessFile(path)) {
				processFile(path);
			}
		}
	}

	/**
	 * Output one match.
	 */
	protected void printMatch(FilePath path, int line, char[] wholeLine) {
		Stdout.format (matchFormat, path.toString(), line, wholeLine);
	}
}

/**
 * DAckCmdLine takes care of command line argument parsing.
 */
class DAckCmdLine : public DAck {

	this(char[][] args) {

		auto arg_parser = new ArgParser();
		arg_parser.bindPosix("print0", &this.parsePrint0);
		arg_parser.bindDefault(&this.defaultArg);
		arg_parser.parse(args[1 .. $]);

		if (rootPaths.length == 0) {
			rootPaths ~= new FilePath(".");
		}
	}

	protected void parsePrint0(char[] ) {
		usePrint0 = true;
	}

	protected void defaultArg(char[] arg, uint ordinal) {
		if (ordinal == 0) {
			regex = Regex(arg);
		} else {
			rootPaths ~= new FilePath(arg);
		}
	}

}

void main(char[][] args) {
	auto dack= new DAckCmdLine(args);

	dack.start();
}
