require "serialport"

# Parámetros del puerto serie de la RPi
port_str = "/dev/ttyUSB0"
baud_rate = 115200
data_bits = 8
parity = SerialPort::NONE
stop_bits = 1
$write_timeout = 0.001 # (seg.)

$rpiSerialPort = SerialPort.new(port_str, baud_rate, data_bits, stop_bits, parity)

def readBytes(sp)
  f = open('serial.log', 'a')
  while true do
    b = sp.readbyte
    f.printf "%c",  b
    f.flush
  end
end


def sendBytes(sp, bs)
	bs.split("").each do |c|
		c = c[0].ord;
    	sp.write(c.chr)
    	sp.flush
		sleep($write_timeout)
	end
end


def sendFrame(sp, data)
  checksum = 0
  data.each {|v| checksum ^= v;}
  # puts ("Checksum: " + checksum.to_s)

  # Preludio
  sendBytes(sp, "AAAA")

  # Tamaño
  sendBytes(sp, [data.length].pack("V")) # little endian, como en ARM

  # Datos
  # sendBytes(sp, data)
  data.each {|v| sendBytes(sp, v.chr); sp.flush; sleep($write_timeout)}

  # Checksum
  sendBytes(sp, [checksum].pack("V")) # little endian, como en ARM
end

def sendTwoStagePayloads(sp, stage0, stage1)
  puts "Enviando etapa-0\n"
  sendFrame(sp, stage0)
  puts "Enviado\n"
  puts "Enviando etapa-1\n"
  sendFrame(sp, stage1)
  puts "Enviado\n"
end

