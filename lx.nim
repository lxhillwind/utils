proc `==`*(x: seq[uint8], y: string): bool =
  if x.len != y.len:
    return false
  for i, ch in y.pairs:
    if x[i] != ch.uint8:
      return false
  return true

template `==`*(x: string, y: seq[uint8]): bool = y == x
