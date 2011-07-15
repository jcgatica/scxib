all:	kace_com_xslt_hexConvert.so

HexConvert.o: HexConvert.c
	gcc -c -arch i386 -arch x86_64 -I /usr/include/libxml2 HexConvert.c -o HexConvert.o

kace_com_xslt_hexConvert.so: HexConvert.o
	gcc -arch i386 -arch x86_64 -dynamiclib -lxml2 -lxslt -o kace_com_xslt_hexConvert.so HexConvert.o

install: all
	cp -p kace_com_xslt_hexConvert.so $(INSTALL_DIR)/resources/

clean:
	rm *.o *.so