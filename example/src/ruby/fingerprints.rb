#TODO: Quería implementar el fingerprints list con un hash pero antes de ruby 1.9 no se garantiza un orden particular
# lo que complica la lógica para indexarlo en la tabla con las address descubiertas de las funciones

$fingerprints = [] # [fname, offset, [fingerprint array]]
$fingerprints << ['printf', 0x34, [0xe92d000e, 0xe52de004, 0xe24dd008, 0xe28dc010, 0xe1a0300c]];
$fingerprints << ['puts', 0x94, [0xe92d40f0, 0xe1a04000, 0xe24dd024]]
$fingerprints << ['rtems_task_wake_after', -0x18, [0xe5945008, 0xe3500000, 0xe1a00005, 0x1a000008]]
$fingerprints << ['pthread_create', -0x4, [0xe2528000, 0xe24dd05c, 0xe1a06000, 0xe1a04001, 0xe1a07003, 0x03a0500e]]
$fingerprints << ['readBytes', -0x30, [0xe3570000, 0xd3a06000, 0xda00001c]]

# En base a los $fingerprints se genera la lista que luego se pasa a findFunctionsAddress
$findFuncList = []
$findFuncList << $fingerprints.length
$fingerprints.each do |fp|
	$findFuncList << fp[2].length
	$findFuncList.concat fp[2]
	$findFuncList << fp[1]
end
