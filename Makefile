all:
	dmd dack.d

rel: release

release:
	dmd dack.d -release -O

all_dsss:
	dsss build

run: all
	./dack

doc:
	dsss build --doc-binaries
	find dsss_docs -type f -exec chmod a+r '{}' \;
	find dsss_docs -type d -exec chmod a+rx '{}' \;
