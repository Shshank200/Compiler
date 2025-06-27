# Default target
all: 
	bison -d TinyC3_22CS30051_22CS30052.y
	flex TinyC3_22CS30051_22CS30052.l
	g++ TinyC3_22CS30051_22CS30052.tab.c lex.yy.c TinyC3_22CS30051_22CS30052_translator.cxx

run:
	./a.out < TinyC3_22CS30051_22CS30052_test1.c > TinyC3_22CS30051_22CS30052_quads1.txt
	./a.out < TinyC3_22CS30051_22CS30052_test2.c > TinyC3_22CS30051_22CS30052_quads2.txt
	./a.out < TinyC3_22CS30051_22CS30052_test3.c > TinyC3_22CS30051_22CS30052_quads3.txt
	./a.out < TinyC3_22CS30051_22CS30052_test4.c > TinyC3_22CS30051_22CS30052_quads4.txt
	./a.out < TinyC3_22CS30051_22CS30052_test5.c > TinyC3_22CS30051_22CS30052_quads5.txt
clean:
	rm -f TinyC3_22CS30051_22CS30052.tab.c TinyC3_22CS30051_22CS30052.tab.h lex.yy.c a.out