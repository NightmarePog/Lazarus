test:
	busted

format:
	stylua src spec types

lint:
	selene src spec types

dev:
	lua src/repl.lua

build:
	lua src/cli.lua build $(FILE)

doc:
	doxygen doc/Doxyfile
