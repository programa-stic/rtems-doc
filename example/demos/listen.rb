require_relative 'common.rb'

# Se queda escuchando el serial port
t1 = Thread.new { readBytes($rpiSerialPort) }
t1.join
