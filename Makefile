# This Makefile is only used by developers.
PYTHON:=python
VERSION:=$(shell $(PYTHON) setup.py --version)
MAINTAINER:=$(shell $(PYTHON) setup.py --maintainer)
AUTHOR:=$(shell $(PYTHON) setup.py --author)
APPNAME:=$(shell $(PYTHON) setup.py --name)
LAPPNAME:=$(shell echo $(APPNAME)|tr "[A-Z]" "[a-z]")
ARCHIVE_SOURCE:=$(LAPPNAME)-$(VERSION).tar.gz
ARCHIVE_WIN32:=$(LAPPNAME)-$(VERSION).exe
GITUSER:=wummel
GITREPO:=$(LAPPNAME)
WEB_META:=doc/web/app.yaml
DEBUILDDIR:=$(HOME)/projects/debian/official
DEBORIGFILE:=$(DEBUILDDIR)/$(LAPPNAME)_$(VERSION).orig.tar.gz
DEBPACKAGEDIR:=$(DEBUILDDIR)/$(LAPPNAME)-$(VERSION)
# Default pytest options
# Note that using -n silently swallows test creation exceptions like
# import errors.
PYTESTOPTS?=--resultlog=testresults.txt --tb=short -n10
CHMODMINUSMINUS:=--
# directory or file with tests to run
TESTS ?= tests
# set test options, eg. to "--verbose"
TESTOPTS=

all:

chmod:
	-chmod -R a+rX,u+w,go-w $(CHMODMINUSMINUS) *
	find . -type d -exec chmod 755 {} \;

dist:
	[ -d dist ] || mkdir dist
	git archive --format=tar --prefix=$(LAPPNAME)-$(VERSION)/ HEAD | gzip -9 > dist/$(ARCHIVE_SOURCE)
	[ ! -f ../$(ARCHIVE_WIN32) ] || cp ../$(ARCHIVE_WIN32) dist

sign:
	[ -f dist/$(ARCHIVE_SOURCE).asc ] || gpg --detach-sign --armor dist/$(ARCHIVE_SOURCE)
	[ -f dist/$(ARCHIVE_WIN32).asc ] || gpg --detach-sign --armor dist/$(ARCHIVE_WIN32)

upload:
	github-upload $(GITUSER) $(GITREPO) \
	  dist/$(ARCHIVE_SOURCE) dist/$(ARCHIVE_WIN32) \
	  dist/$(ARCHIVE_SOURCE).asc dist/$(ARCHIVE_WIN32).asc

homepage:
# update metadata
	@echo "version: \"$(VERSION)\"" > $(WEB_META)
	@echo "name: \"$(APPNAME)\"" >> $(WEB_META)
	@echo "lname: \"$(LAPPNAME)\"" >> $(WEB_META)
	@echo "maintainer: \"$(MAINTAINER)\"" >> $(WEB_META)
	@echo "author: \"$(AUTHOR)\"" >> $(WEB_META)
# update documentation and release website
	$(MAKE) -C doc
	$(MAKE) -C doc/web release

release: distclean releasecheck
	$(MAKE) dist sign upload homepage tag register deb

tag:
	git tag upstream/$(VERSION)
	git push --tags origin upstream/$(VERSION)

register:
	@echo "Register at Python Package Index..."
	$(PYTHON) setup.py register
	@echo "Submit to freecode..."
	freecode-submit < $(LAPPNAME).freecode

releasecheck: check
	git checkout master
	@if egrep -i "xx\.|xxxx|\.xx" doc/changelog.txt > /dev/null; then \
	  echo "Could not release: edit doc/changelog.txt release date"; false; \
	fi
	@if [ ! -f ../$(ARCHIVE_WIN32) ]; then \
	  echo "Missing WIN32 distribution archive at ../$(ARCHIVE_WIN32)"; \
	  false; \
	fi
	@if ! grep "Version: $(VERSION)" $(LAPPNAME).freecode > /dev/null; then \
	  echo "Could not release: edit $(LAPPNAME).freecode version"; false; \
	fi
	$(PYTHON) setup.py check --restructuredtext
	git checkout debian
	@if ! head -1 debian/changelog | grep "$(VERSION)" > /dev/null; then \
	  echo "Could not release: update debian/changelog version"; false; \
	fi
	@if head -1 debian/changelog | grep UNRELEASED >/dev/null; then \
	  echo "Could not release: set debian/changelog release name"; false; \
	fi
	git checkout master

# The check programs used here are mostly local scripts on my private system.
# So for other developers there is no need to execute this target.
check:
	check-copyright
	check-pofiles -v
	py-tabdaddy
	py-unittest2-compat tests/
	$(MAKE) doccheck
	$(MAKE) pyflakes

doccheck:
	py-check-docstrings --force \
	  dosagelib/*.py \
	  dosage \
	  scripts \
	  *.py

pyflakes:
	pyflakes dosage dosagelib scripts tests doc/web

count:
	@sloccount dosage dosagelib/*.py

clean:
	find . -name \*.pyc -delete
	find . -name \*.pyo -delete
	rm -rf build dist

distclean: clean
	rm -rf build dist $(APPNAME).egg-info $(LAPPNAME).prof test.sh
	rm -f _$(APPNAME)_configdata.py MANIFEST

localbuild:
	$(PYTHON) setup.py build

test:	localbuild
	env LANG=en_US.utf-8 http_proxy="" $(PYTHON) -m pytest $(PYTESTOPTS) $(TESTOPTS) $(TESTS)

testall:	localbuild
	env LANG=en_UR.utf-8 http_proxy="" TESTALL=1 $(PYTHON) -m pytest $(PYTESTOPTS) $(TESTOPTS) $(TESTS)

deb:
# Build an official .deb package; only useful for Debian maintainers.
# To build a local .deb package, use:
# $ sudo apt-get build-dep dosage; apt-get source dosage; cd dosage-*; debuild binary
	[ -f $(DEBORIGFILE) ] || cp dist/$(ARCHIVE_SOURCE) $(DEBORIGFILE)
	sed -i -e 's/VERSION_$(LAPPNAME):=.*/VERSION_$(LAPPNAME):=$(VERSION)/' $(DEBUILDDIR)/$(LAPPNAME).mak
	[ -d $(DEBPACKAGEDIR) ] || (cd $(DEBUILDDIR); \
	  patool extract $(DEBORIGFILE); \
	  cd $(CURDIR); \
	  git checkout debian; \
	  cp -r debian $(DEBPACKAGEDIR); \
	  rm -f $(DEBPACKAGEDIR)/debian/.gitignore; \
	  git checkout master)
	$(MAKE) -C $(DEBUILDDIR) $(LAPPNAME)_clean $(LAPPNAME)

update-copyright:
# update-copyright is a local tool which updates the copyright year for each
# modified file.
	update-copyright --holder="$(MAINTAINER)"

changelog:
# github-changelog is a local tool which parses the changelog and automatically
# closes issues mentioned in the changelog entries.
	github-changelog $(DRYRUN) $(GITUSER) $(GITREPO) doc/changelog.txt

.PHONY: update-copyright deb test clean distclean count pyflakes changelog
.PHONY: doccheck check releasecheck release dist chmod localbuild sign
.PHONY: register tag homepage
