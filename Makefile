all:
	dmd dack.d

r: all run

run:
	./dack $*
