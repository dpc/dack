import
	tango.core.Exception,
	tango.io.FileScan,
	tango.io.Stdout,
	tango.io.stream.FileStream,
	tango.io.stream.LineStream,
	tango.text.Regex,
	tango.text.stream.LineIterator
	;

class DAck {
	Regex regex;
	char[][] ignoredDirNames = [".svn", ".git"];
	char[][] ignoredFileNames = [".svn", ".git"];
	char[][] ignoredFileExts = ["o", ".a"];

	struct Match {
		FilePath path;
		int line;
	}

	Match[] matches;

	this(char[] regex) {
		this.regex = Regex(regex);
	}

	bool shouldProcessDir(FilePath path) {
		auto name = path.name();

		foreach(iname; ignoredDirNames) {
			if (name == iname) {
				return false;
			}
		}

		return true;
	}

	void processDir(FilePath path) {
		foreach (entry; path.toList) {
			if (entry.isFolder()) {
				if (shouldProcessDir(entry)) {
					processDir(entry);
				}
			} else {
				if (shouldProcessFile(entry)) {
					processFile(entry);
				}
			}
		}
	}

	void processFile(FilePath path) {
		auto input = new LineInput (new FileInput(path.toString()));
		scope(exit) { input.close; }
		auto line_num = 0;
		try {
			foreach (line; input) {
				if (regex.test(line)) {
					addMatch(path, line_num);
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

	void addMatch(FilePath path, int line) {
		Match new_match;
		new_match.path = path;
		new_match.line = line;

		// TODO: make more efficient
		matches ~= new_match;
	}

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

	void printMatches() {
		foreach(match; matches) {
			 Stdout.format ("{}:{}\n", match.path.toString(), match.line);
		}
	}
}

void main(char[][] args) {
	if (args.length < 2) {
		return -1;
	}

	auto regex = args[1];
	auto dack = new DAck(regex);

	dack.processDir(new FilePath("."));
	dack.printMatches();
}
