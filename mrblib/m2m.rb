class M2M
  def initialize(send_spec, recv_spec)
    @pull = CZMQ::Zsock.new ZMQ::PULL
    @pull.connect(send_spec)
    @pub = CZMQ::Zsock.new ZMQ::PUB
    @pub.connect(recv_spec)
  end

  SPACE = ' '

  def recv
    sender, conn_id, path, rest = CZMQ::Zframe.recv(@pull).to_str.split(SPACE, 4)
    headers, rest = TNetStrings.parse(rest)
    headers = JSON.parse(headers)
    body, _ = TNetStrings.parse(rest)
    [sender, conn_id, path, headers, body]
  end

  def send(sender, conn_id, body)
    conn_id = conn_id.join(SPACE) if conn_id.respond_to?(:join)
    CZMQ::Zframe.new("#{sender} #{TNetStrings.dump(conn_id)} #{body}").send(@pub)
  end

  def close(sender, conn_id)
    send(sender, conn_id, nil)
  end

  METHOD = 'METHOD'
  WEBSOCKET = 'WEBSOCKET'
  FLAGS = 'FLAGS'

  def recv_websocket
    sender, conn_id, path, headers, body = recv
    unless headers[METHOD] == WEBSOCKET
      close(sender, conn_id)
      raise "not a websocket message"
    end

    flags = Integer(headers[FLAGS], 16)
    fin = flags & 0x80 == 0x80
    rsvd = flags & 0x70
    opcode =  case (flags & 0xf)
              when 0x0
                :continuation
              when 0x1
                :text
              when 0x2
                :binary
              when 0x8
                :connection_close
              when 0x9
                :ping
              when 0xA
                :pong
              else
                flags & 0xf
              end

    [sender, conn_id, path, headers, fin, rsvd, opcode, body]
  rescue ArgumentError => e
    close(sender, conn_id)
    raise e
  end

  CSTAR = 'C*'

  def send_websocket(sender, conn_id, data, opcode = 1, rsvd = 0)
    data = String(data)
    len = data.bytesize
    raise ArgumentError, "len musn't be negative" if len < 0
    header =  if len <= 125
                [0x80|rsvd<<4|opcode, len]
              elsif len >= 126 && len <= 65535
                [0x80|rsvd<<4|opcode, 126, (len >> 8) & 255, (len) & 255]
              else
                [
                  0x80|rsvd<<4|opcode,
                  127,
                  (len >> 56) & 255,
                  (len >> 48) & 255,
                  (len >> 40) & 255,
                  (len >> 32) & 255,
                  (len >> 24) & 255,
                  (len >> 16) & 255.
                  (len >> 8) & 255,
                  (len) & 255
                ]
              end.pack(CSTAR)
    send(sender, conn_id, "#{header}#{data}")
  end
end
