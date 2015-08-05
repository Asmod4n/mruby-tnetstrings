class Zurl
  class Error < StandardError; end

  GET = 'GET'
  ID = 'id'
  MORE = 'more'
  TYPE = 'type'
  KA = 'keep-alive'
  FROM = 'from'
  DELIMETER = ''
  ERROR = 'error'
  BODY = 'body'
  SPACE = ' '

  def initialize(client_id,
    push = 'ipc:///tmp/zurl-in',
    router = 'ipc:///tmp/zurl-in-stream',
    sub = 'ipc:///tmp/zurl-out',
    req = 'ipc:///tmp/zurl-req')

    @client_id = client_id
    @push = CZMQ::Zsock.new ZMQ::PUSH
    @push.connect(push)
    @router = CZMQ::Zsock.new ZMQ::ROUTER
    @router.connect(router)
    @sub = CZMQ::Zsock.new ZMQ::SUB
    @sub.subscribe = client_id
    @sub.connect(sub)
    @req = CZMQ::Zsock.new ZMQ::REQ
    @req.connect(req)
  end

  def get(uri, headers = nil)
    req = {id: RandomBytes.buf(16), method: GET, uri: uri}
    req[:headers] = headers if headers
    CZMQ::Zframe.new("T#{TNetStrings.dump(req)}").send(@req)
    reply = CZMQ::Zframe.recv(@req)
    TNetStrings.parse(reply.to_str[1, -1])
  end

  def queue(meth, uri, headers = nil, body = nil)
    id = RandomBytes.buf(16)
    seq = 0
    req = {from: @client_id, id: id, seq: seq, stream: true, credits: 32767, method: meth, uri: uri}
    req[:headers] = headers if headers
    req[:more] = true if body
    CZMQ::Zframe.new("T#{TNetStrings.dump(req)}").send(@push)
    seq += 1
    loop do
      reply = CZMQ::Zframe.recv(@sub).to_str
      at = reply.index SPACE
      data, _ = TNetStrings.parse(reply.slice(at+2..-1))
      next unless data[ID] == id
      puts data
      break if (data[ERROR]) || (!data[TYPE] && !data[MORE])
      if data[TYPE] == KA
        req = {from: @client_id, id: id, seq: seq, type: KA}
        @router.sendx(data[FROM], DELIMETER, "T#{TNetStrings.dump(req)}")
        seq += 1
        next
      end
      if data[BODY]
        req = {from: @client_id, id: id, seq: seq, type: :credit, credits: 32767}
        @router.sendx(data[FROM], DELIMETER, "T#{TNetStrings.dump(req)}")
        seq += 1
      end
    end
  end
end
