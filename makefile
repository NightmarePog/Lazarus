format:
	stylua types

lint:
	selene types

# Rebuild the self-hosted compiler from compiler/ into bin/lazarusc.lua,
# seeded by the existing bin/ binary. Verifies the fixpoint first.
selfhost:
	bin/build-compiler

# Compile a .laz file with the self-hosted compiler (writes ./Main.lua).
selfbuild:
	lua bin/lazarusc.lua $(FILE)

doc:
	doxygen doc/Doxyfile
