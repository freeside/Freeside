#!/usr/bin/make

help:
	@echo "supported targets: aspdocs masondocs alldocs perl-modules"
	@echo "                   install-perl-modules install clean"

aspdocs: httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf aspdocs
	cp -pr httemplate aspdocs
	touch aspdocs

masondocs: httemplate/* httemplate/*/* httemplate/*/*/* httemplate/*/*/*/* httemplate/*/*/*/*/*
	rm -rf masondocs
	cp -pr httemplate masondocs
	( cd masondocs; \
	  ../bin/masonize; \
	)
	touch masondocs

alldocs: aspdocs masondocs

FS/Makefile:
	cd FS
	perl Makefile.PL

perl-modules:
	cd FS; \
	[ -e Makefile ] || perl Makefile.PL; \
	make

install-perl-modules: perl-modules
	cd FS; \
	make install

install: install-perl-modules

deploy: install
	/etc/init.d/apache restart

clean:
	rm -rf aspdocs masondocs
	cd FS; \
	make clean

