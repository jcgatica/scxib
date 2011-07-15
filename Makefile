INSTALL_DIR=`pwd`
all: hexConvert

hexConvert:
	make -C XSLT_HexExtensions install INSTALL_DIR=$(INSTALL_DIR)

clean:
	make -C XSLT_HexExtensions clean

