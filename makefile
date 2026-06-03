test:
	busted

format:
	stylua src spec types

lint:
	selene src spec types

dev:
	lua src/repl.lua
