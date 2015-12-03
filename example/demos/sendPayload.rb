require_relative "common"


# Seleccionar uno de los payloads y comentar el resto

require_relative "pthreadPaylaod"
# require_relative "evt_irq_corruption"


# Se envian los payloads
sendTwoStagePayloads($rpiSerialPort, $stage0.packPayload, $stage1.packPayload)


# Para el ejemplo que usa RPC
rtems_task_wake_after_address = 0xf7d0
if (defined? $rpcEnabled) != nil and $rpcEnabled == true
  while true do
    puts "Presionar Enter para enviar RPC\n"
    gets
    sendFrame($rpiSerialPort, [100, 0, 0, 0, rtems_task_wake_after_address].pack("V*").bytes.to_a) #  (100 ticks) [R0, R1, R2, R3, F_ADDR]
    puts "Enviado\n"
  end
end
