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

    flags = headers[FLAGS].to_i(16)
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
  end

  CSTAR = 'C*'

  def send_websocket(sender, conn_id, data, opcode = 1, rsvd = 0)
    header = [0x80|rsvd<<4|opcode]
    len = data.bytesize
    if len <= 125
      header[1] = len
    elsif len >= 126 && len <= 65535
      header[1] = 126
      header[2] = (len >> 8) & 255
      header[3] = (len) & 255
    else
      header[1] = 127
      header[2] = (len >> 56) & 255
      header[3] = (len >> 48) & 255
      header[4] = (len >> 40) & 255
      header[5] = (len >> 32) & 255
      header[6] = (len >> 24) & 255
      header[7] = (len >> 16) & 255
      header[8] = (len >> 8) & 255
      header[9] = (len) & 255
    end
    send(sender, conn_id, "#{header.pack(CSTAR)}#{data}")
  end
end
