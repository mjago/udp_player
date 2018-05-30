require "socket"
require "libao"
require "uri"
include Libao

class UdpPlayer
  MSG_SIZE = 4096

  def initialize
    @ao = Ao.new
    @done = 0
    @playdata = Channel(Bytes).new
    @playsize = Channel(Int32).new
    @server = UDPSocket.new
    @quit = false
    init_audio
    bind_to_server
  end

  def play
    spawn do
      message = Bytes.new(MSG_SIZE)
      while @quit == false
        size, client_addr = @server.receive(message)
        @playdata.send(message)
        @playsize.send(size)
      end
    end

    spawn do
      while @quit == false
        message = @playdata.receive
        size = @playsize.receive
        @ao.play(message, size)
      end
    end
  end

  def exit
    @server.close
    @ao.exit
    @quit = true
  end

  private def bind_to_server
    adr = address
    @server.bind(adr[:host], adr[:port])
  end

  private def init_audio
    bits = 16
    rate = 48000
    channels = 1
    byte_format = LibAO::Byte_Format::AO_FMT_BIG
    @ao.set_format(bits, rate, channels, byte_format, matrix = nil)
    @ao.open_live
  end

  private def address : {host: String, port: Int32}
    if ARGV.size == 2
      host, port = ARGV[0], ARGV[1].to_i
    else
      host, port = "localhost", 7355
    end
    {host: host, port: port}
  end
end

player = UdpPlayer.new
player.play
player.exit if gets
