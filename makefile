format:
	stylua types

lint:
	selene types

# Rebuild the self-hosted compiler from compiler/ into bin/lazec.lua,
# seeded by the existing bin/ binary. Verifies the fixpoint first.
selfhost:
	bin/build-compiler

# Compile a .laz file with the self-hosted compiler (writes ./Main.lua).
selfbuild:
	lua bin/lazec.lua $(FILE)

doc:
	doxygen doc/Doxyfile

.PHONY: selfhost selfbuild book book-serve

book:
	$(HOME)/.cargo/bin/mdbook build book

book-serve:
	$(HOME)/.cargo/bin/mdbook serve book
