LUA= $(shell echo `which lua`)
LUA_BINDIR= $(shell echo `dirname $(LUA)`)
LUA_PREFIX= $(shell echo `dirname $(LUA_BINDIR)`)
LUA_SHAREDIR=$(LUA_PREFIX)/share/lua/5.1

argcheck:

install:
	mkdir -p $(LUA_SHAREDIR)
	cp argcheck.lua $(LUA_SHAREDIR)
	cp argwarn.lua $(LUA_SHAREDIR)

uninstall: 
	-rm $(LUA_SHAREDIR)/argcheck.lua
	-rm $(LUA_SHAREDIR)/argwarn.lua
