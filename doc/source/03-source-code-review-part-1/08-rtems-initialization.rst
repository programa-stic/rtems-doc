Inicialización de RTEMS
=======================

La documentación más completa sobre la inicialización de RTEMS se encuentra en la `"BSP and Device Driver Development Guide" <http://docs.rtems.org/doc-current/share/rtems/pdf/bsp_howto.pdf>`_.

El primer código en ejecutarse luego de que se iniciarse el equipo (o luego de un *reset*) se encuentra en el archivo ``start.S`` (código ensamblador), el cual tiene distintas versiones según la arquitectura y el tipo de BSP utilizado, por ejemplo para ARM se enecuentra en ``./c/src/lib/libbsp/arm/shared/start/start.S``. Las funciones más importantes que cumple son:

* Inicializar la pila.

* Poner en cero la sección de memoria ``.bss``.

* Copiar datos inicializados de la memoria ROM a la RAM.

Este código trata de ser lo más pequeño posible, su objetivo es preparar todo lo necesario para que pueda ejecutarse el código de inicialización en C, en la función ``boot_card()``, a la que llama ``start.S`` finalizando su parte de la inicialización.

La función ``boot_card()``, ubicada en ``c/src/lib/libbsp/shared/bootcard.c``, termina la inicialización de RTEMS, y es la que ejecuta la mayoría del código. Las tareas principales que realiza son:

* Deshabilitar las interrupciones.

* Llama a la función ``bsp_start()`` que se encarga de ejecutar las rutinas específicas para la inicialización de la BSP (por ejemplo iniciar la MMU).

* Llama a la función ``bsp_work_area_initialize()`` que inicializa los *heaps* de trabajo tanto para RTEMS (*RTEMS Workspace*) como para la aplicación del usuario (*C Program Heap*).

* Llama a la función ``rtems_initialize_data_structures()`` para poner al sistema operativo en un estado donde puedan crearse objetos del sistema.

* Llama a la función ``bsp_libc_init()`` para inicializar la librería C.

* Llama a la función ``rtems_initialize_device_drivers()`` para inicializar el conjunto de dispositivos que fueron configurados estáticamente en la tabla de configuración.

Cuando termina la inicialización se llama la función ``rtems_initialize_start_multitasking()`` que realiza un cambio de contexto hacia la primera función definida por el usuario (llamada ``Init``), la cuál comenzará a ejecutarse a partir de este punto. Con esto se da por finalizada la inicialización de RTEMS.

Cuando la aplicación del usuario llame a ``exit()`` (que a su vez llama a ``rtems_shutdown_executive()``) terminará su ejecución, retornando al contexto guardado anteriormente en ``boot_card()``. En este punto se habrá alcanzado el estado final del sistema.
