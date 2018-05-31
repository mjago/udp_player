require "socket"
require "libao"

include Libao

class UdpPlayer
  MSG_SIZE     =  4096
  BITS         =    16
  RATE         = 48000
  CHANNELS     =     1
  BYTE_FORMAT  = LibAO::Byte_Format::AO_FMT_BIG
  DEFAULT_HOST = "localhost"
  DEFAULT_PORT = 18080

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
    puts "Server listening on #{adr[:host]}:#{adr[:port]}"
  end

  private def init_audio
    @ao.set_format(BITS, RATE, CHANNELS, BYTE_FORMAT, matrix = nil)
    @ao.open_live
  end

  private def address
    return {host: ARGV[0], port: ARGV[1].to_i} if ARGV.size == 2
    {host: DEFAULT_HOST, port: DEFAULT_PORT}
  end
end

player = UdpPlayer.new
player.play
player.exit if gets
