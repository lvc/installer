prefix ?= /usr

.PHONY: install
install:
	perl installer.pl -install -prefix "$(prefix)" "$(target)"

uninstall:
	perl installer.pl -remove -prefix "$(prefix)" "$(target)"
