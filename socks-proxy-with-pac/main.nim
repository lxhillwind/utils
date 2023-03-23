# TODO pipe in doRelay.
# TODO proxy to socks5 / direct based on domainname.
# in short, how to read from two sources asyncrously?

import asyncnet, asyncdispatch
import sugar
import strutils
import sequtils


var clients {.threadvar.}: seq[AsyncSocket]


proc doRelay(client: AsyncSocket, reqAddr: string, reqPort: int) {.async.} =
  ## ver rep rsv atyp (len)bnd.addr bnd.port (9050)  # TODO
  #await client.send("\x05\x00\x00\x01\x09127.0.0.1\x35\x90")
  await client.send("\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00")
  var target = newAsyncSocket(buffered=false)
  await target.connect(reqAddr, Port(reqPort))
  while true:
    var dataStr: string
    dataStr = await client.recv(10240)
    if dataStr.len > 0:
      await target.send(dataStr)
    else:
      return
    dataStr = await target.recv(10240)
    if dataStr.len > 0:
      await client.send(dataStr)
    else:
      return


proc processClient(client: AsyncSocket) {.async.} =
  type States = enum
    Req
    Auth
    Con
    Est
  var state: States = Req
  while true:
    case state
    of Req:
      let dataStr = await client.recv(3)
      let data: seq[int] = dataStr.map(i => i.ord)
      if data[0] != 5:
        echo "invalid sock ver: " & $data[0]
        return
      if data[2] != 0:
        echo "method unless 0 is not supported: " & $data[2]
        return
      state = Con
      asyncCheck client.send("\x05\x00")
    of Con:
      # use large buf len in case of long domain name in req.
      let dataStr = await client.recv(1024)
      if dataStr.len() == 0:
        # finish.
        return
      let data: seq[int] = dataStr.map(i => i.ord)
      if data[0] != 5:
        echo "invalid sock ver: " & $data[0]
        return
      if data[1] != 1:
        # CMD
        # CONNECT X'01'
        # BIND X'02'
        # UDP ASSOCIATE X'03'
        echo "unsupported CMD: " & $data[1]
        return
      case data[3]
      of 1, 3, 4:
        # ipv4, domainname, ipv6
        discard
      else:
        echo "unsupported ATYP: " & $data[3]
        return
      # data[4] seems to be addr length.
      var reqAddr = data[5..data.len()-3].map(i => i.chr).join("")
      var reqPort = data[data.len()-2] * 256 + data[data.len()-1]
      echo reqAddr, ":", reqPort  # logging
      asyncCheck doRelay(client, reqAddr, reqPort)
      return
    else:
      echo "auth not supported. (unreachable)"
      quit 1


proc serve() {.async.} =
  # buffered=false is required; since we may not read enough data (in Con / Est state).
  var server = newAsyncSocket(buffered=false)
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(Port(9050))
  server.listen()

  while true:
    let client = await server.accept()
    clients.add client

    asyncCheck processClient(client)


asyncCheck serve()
runForever()
