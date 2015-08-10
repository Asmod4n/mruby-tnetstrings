class Zurl
  class Error < StandardError; end

  GET = 'GET'
  ID = 'id'
  MORE = 'more'
  TYPE = 'type'
  KEEP_ALIVE = 'keep-alive'
  FROM = 'from'
  DELIMETER = ''
  ERROR = 'error'
  BODY = 'body'
  SPACE = ' '
  CREDITS = 'credits'

  def initialize(client_id,
    push = 'ipc:///tmp/zurl-in',
    router = 'ipc:///tmp/zurl-in-stream',
    sub = 'ipc:///tmp/zurl-out',
    dealer = 'ipc:///tmp/zurl-req')

    @client_id = client_id
    @push = CZMQ::Zsock.new ZMQ::PUSH
    @push.connect(push)
    @router = CZMQ::Zsock.new ZMQ::ROUTER
    @router.connect(router)
    @sub = CZMQ::Zsock.new ZMQ::SUB
    @sub.subscribe = client_id
    @sub.connect(sub)
    @dealer = CZMQ::Zsock.new ZMQ::REQ
    @dealer.connect(dealer)
  end

  def get(uri, headers = nil)
    req = {id: RandomBytes.buf(16), method: GET, uri: uri}
    req[:headers] = headers if headers
    @dealer.sendx(DELIMETER, "T#{TNetStrings.dump(req)}")
    TNetStrings.parse(CZMQ::Zframe.recv(@dealer).to_str.slice(1..-1))
  end

  def queue(meth, uri, headers = nil, body = nil)
    id = RandomBytes.buf(16)
    if block_given?
      seq = 0
      req = {from: @client_id, id: id, seq: seq, stream: true, credits: 32767, method: meth, uri: uri}
      req[:headers] = headers if headers
      if body
        outcredits = 0
        pos = 0
      end
      CZMQ::Zframe.new("T#{TNetStrings.dump(req)}").send(@push)
      seq += 1
      loop do
        reply = CZMQ::Zframe.recv(@sub).to_str
        data, _ = TNetStrings.parse(reply.byteslice(reply.index(SPACE)+2..-1))
        next unless data[ID] == id
        yield data unless data[TYPE]
        break if (data[ERROR]) || (!data[TYPE] && !data[MORE])
        if data[TYPE] == KEEP_ALIVE
          req = {from: @client_id, id: id, seq: seq, type: KEEP_ALIVE}
          @router.sendx(data[FROM], DELIMETER, "T#{TNetStrings.dump(req)}")
          seq += 1
          next
        end
        if data[BODY]
          req = {from: @client_id, id: id, seq: seq, type: :credit, credits: 32767}
          @router.sendx(data[FROM], DELIMETER, "T#{TNetStrings.dump(req)}")
          seq += 1
        end
        if body
          outcredits += data[CREDITS] if data[CREDITS]
          if outcredits > 0 && pos < body.bytesize
            chunk = body.byteslice(pos..outcredits)
            req = {from: @client_id, id: id, seq: seq, body: chunk}
            pos += chunk.bytesize
            req[:more] = true if pos < body.bytesize
            @router.sendx(data[FROM], DELIMETER, "T#{TNetStrings.dump(req)}")
            seq += 1
            outcredits -= chunk.bytesize
          end
        end
      end
    else
      req = {from: @client_id, id: id, method: meth, uri: uri}
      req[:headers] = headers if headers
      req[:body] = body if body
      CZMQ::Zframe.new("T#{TNetStrings.dump(req)}").send(@push)
    end
  end
end
