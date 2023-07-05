import os


proc processDir(dir: string) =
  if dirExists(dir & "/.git"):
    echo dir
    if not fileExists(dir & "/.gitmodules"):
      # do not go deeper for git without submodule
      return
  if fileExists(dir & "/.git"):
    # submodule and custom marker.
    echo dir
    return

  # blacklist
  case dir.splitPath().tail
  of "venv", "node_modules":
    return
  else:
    discard

  for ty, item in walkDir(dir):
    case ty
    of pcDir:
      processDir(item)
    else:
      discard

var dirs: seq[string] = commandLineParams()

for i in dirs:
  processDir(i)
