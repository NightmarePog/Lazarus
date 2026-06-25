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

# Rebuild the self-hosted compiler from compiler/ into bin/lazarusc.lua,
# seeded by the existing bin/ binary (no src/). Verifies the fixpoint first.
selfhost:
	bin/build-compiler

# Compile a .laz file with the self-hosted compiler (writes ./Main.lua).
selfbuild:
	lua bin/lazarusc.lua $(FILE)

doc:
	doxygen doc/Doxyfile
