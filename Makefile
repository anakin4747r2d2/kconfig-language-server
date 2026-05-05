
PREFIX ?= /usr/local

.PHONY: all test lint install dev-install uninstall install-vscode-ext

all:
	nix --extra-experimental-features 'nix-command flakes' develop --command make test lint

lint:
	shellcheck --external-sources --shell=bash kconfig-language-server test/test_kconfig-language-server.bats test/test_lsts.bats

test:
	bats --verbose-run test/test_*

install:
	install -d $(DESTDIR)$(PREFIX)/bin/
	install -m 0755 kconfig-language-server $(DESTDIR)$(PREFIX)/bin/

dev-install:
	install -d $(DESTDIR)$(PREFIX)/bin/
	ln -sf $$PWD/kconfig-language-server $(DESTDIR)$(PREFIX)/bin/kconfig-language-server

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/kconfig-language-server

install-vscode-ext:
	mkdir -p ~/.vscode-oss/extensions/kconfig-language-server-0.0.1
	cp -r vscode-extension/. ~/.vscode-oss/extensions/kconfig-language-server-0.0.1
