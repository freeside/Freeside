#!/usr/bin/make

default:
	@echo "supported targets: aspdocs masondocs clean"

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

clean:
	rm -rf aspdocs masondocs

