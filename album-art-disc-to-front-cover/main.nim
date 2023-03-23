# reference: https://id3.org/id3v2.3.0

import lx

import strutils
import math
import parseopt

proc eprint(msg: string) =
  try: stderr.write(msg & "\n")
  except IOError: discard

proc abort(msg: string) {. noreturn .} =
  eprint(msg)
  quit(1)

proc writeHelp(code: int=0) {. noreturn .} =
  eprint("""
  update id3 tag in .mp3 files:
    convert disc type cover to front cover.

  usage: {exe} [files to handle...]
  """)
  quit(code)

proc handleFile(filename: string) =
  let file = open(filename, fmReadWriteExisting)
  var buf = newSeq[uint8](1024)

  # ID3v2 tag header: 10 bytes. {{{1
  assert 10 == file.readBytes(buf, 0, 10)

  # ID3v2/file identifier
  if buf[0..2] != "ID3":
    abort("is not id3: " & filename)

  # id (read above): 3; ver: 2; flag: 1; size: 4 byte(s)
  # so size begin from buf[6];
  # most significant bit of every byte is 0 and discarded.
  let tagSize = buf[6] * (128'u64 ^ 3) + buf[7] * (128'u64 ^ 2) + buf[8] * (128'u64) + buf[9]

  # skip extended header {{{1
  assert 4 == file.readBytes(buf, 0, 4)
  let extendedHeaderSize =
    if buf[3] == 6:
      6
    elif buf[3] == 10:
      10
    else:
      0
  # if extended header is not exist, we need to go back.
  file.setFilePos(10 + extendedHeaderSize)

  #echo "tag size: " & $(tagSize + 10)
  # iterate on frame {{{1
  block iterOnFrame:
    while file.getFilePos.uint64 < tagSize + 10:
      assert 10 == file.readBytes(buf, 0, 10)
      # frameId must consist of uppercase (and optional 0-9)
      for ch in buf[0..3]:
        let ch = ch.char
        if not (
          (ch >= 'A' and ch <= 'Z') or (ch >= '0' and ch <= '9')
          ):
          #let pos = file.getFilePos - 4
          #abort("invalid header at pos " & $pos & ": " & buf[0..3])
          break iterOnFrame
      let frameId = buf[0..3]
      let frameSize = buf[4] * (256'u64 ^ 3) + buf[5] * (256'u64 ^ 2) + buf[6] * (256'u64) + buf[7]
      #echo frameId & " " & $frameSize

      if frameId == "APIC":
        file.setFilePos(1, fspCur)  # skip Text encoding
        while file.readChar != '\0':  # skip MIME type
          discard  # read until \0
        var picType = file.readChar.uint8
        #echo picType

        if picType == 6:
          echo "filename: " & filename & " picType: " & $picType
          file.setFilePos(-1, fspCur)
          file.write('\x03')
          echo "  updated."

        break iterOnFrame

      file.setFilePos(frameSize.int64, fspCur)

proc main() {. raises: [] .} =
  var filesToHandle: seq[string] = @[]

  for kind, key, _ in getopt():
    case kind
    of cmdArgument:
      filesToHandle.add(key)
    of cmdLongOption, cmdShortOption:
      case key
      of "help", "h":
        writeHelp()
      else:
        writeHelp(-1)
    else:
      assert false  # cannot happen

  if filesToHandle.len == 0:
    writeHelp()

  var res = 0
  for filename in filesToHandle:
    try: handleFile(filename)
    except IOError as e:
      eprint(e.msg)
      res = 1
  quit(res)

main()
