package = "argcheck"
version = "scm-1"
source =
{
  url = "git://github.com/geoffleyland/argcheck.git",
  branch = "master"
}
description =
{
  summary = "Checks function arguments against specifications parsed from comments",
  homepage = "http://github.com/geoffleyland/argcheck",
  license = "MIT/X11",
  maintainer = "Geoff Leyland <geoff.leyland@incremental.co.nz>"
}
dependencies = { "lua >= 5.1" }
build =
{
  type = "builtin",
  modules =
  {
    argcheck = "argcheck.lua",
    argwarn = "argwarn.lua",
  },
}
