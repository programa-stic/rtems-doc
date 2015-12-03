Relevamiento del Código Fuente de RTEMS - Parte I
*************************************************

En esta sección se detalla la estructura de RTEMS. La misma es el resultado del
relevamiento de código de RTEMS.

RTEMS se compila junto con el programa de usuario a ejecutar y las librerías que serán necesarias, todas de forma estática, en un solo archivo final. Nada se carga en forma dinámica, el sistema corre un único programa de usuario. Todas las funciones que no sean utilizadas se descartan durante el proceso de compilación, por lo que el sistema operativo se ajusta a cada aplicación, debe crearse una versión distinta por cada programa que se quiera ejecutar en RTEMS.


No hay llamadas a sistema (*syscalls*) en el sentido tradicional (como en Linux por ejemplo), donde el usuario llama a una función de envoltorio (*wrapper*) que se encarga de realizar una interrupción para pasar el control al sistema operativo. En cambio, todas las funcionalidades del sistema opertivo están expuestas en funciones de C que se ejecutan normalmente (más allá de que internamente puedan tener algo de código ensamblador dentro) sin utilizar interrupciones ni modificando el flujo de ejecución. Llamar a una función del sistema operativo tiene la misma mecánica que llamar a una función del programa del usuario.


No se suelen utilizar las unidades de manejo de memoria (MMU) provistas por la mayoría de los procesadores, RTEMS trabaja en un esquema de memoria plano donde toda la memoria es accesible desde cualquier punto de ejecución del sistema, generando un acople entre el sistema operativo y la aplicación del usuario.


RTEMS implementa la API de POSIX 1003 (POSIX 1003.13-2003 Profile 52) que corresponde a un sistema de proceso único con varios hilos (*threads*) de ejecución, a los cuales RTEMS denomina tareas (*tasks*). Por lo mencionado en párrafos anteriores estas tareas pueden interactuar entre sí directamente (aunque RTEMS proporciona mecanismos explícitos de IPC). A estas tareas se les agrega la tarea osciosa (*idle*) con la menor prioridad, que se ejecuta cuando no hay nada más que hacer, realizando un ciclo (*loop*) infinito.


El código de RTEMS está divido entre las partes que son dependientes de la arquitectura y el equipo (BSP) donde corre, y las partes independientes de estas. A veces esta separacíón no suele ser muy explícita y puede resultar dificultoso seguir la línea de ejecución del código, por lo que hay que tener en cuenta que a veces la ejecución sigue dentro de alguna función definida específicamente para el BSP utilizado.


RTEMS está escrito en C pero está orientado al paradigma de objetos. Este paradigma se implementa creando estrcuturas de C (objetos) que luego son incluídos dentro de otras estructuras, de manera que las primeras estructuras serían los objetos padre, y las estructuras que las contienen serían los objetos hijos que descienden de estas. Estos objetos se suelen manipular mediante punteros que son convertidos (*cast*) a distintos tipos de estructuras, de manera de poder interpretar a la estructura como el objeto padre o el hijo, según corresponda.


No cuenta con interfaz gŕafica para interactuar, solo con una consola que implementa algunos de los comandos especificados en la POSIX (además de otros comandos extra, propios de RTEMS).


Se basa en la *Newlib* para construir su librería de C estándar, a la cuál le realiza distintas modificaciones para adaptarla a la arquitectura y BSP utilizados (en la parte de más bajo nivel de la librería).


Las funciones de manejo de memoria clásicas como ``malloc()`` y ``free()`` utilizan directamente los mismos mecanismos de manejo de memoria internos de RTEMS. La única diferencia es que RTEMS y la aplicación del usuario obtienen los bloques de memoria de distintos sectores (*heaps*), de manera que uno no pueda corromper al otro.

.. toctree::
   :maxdepth: 1

   01-layout.rst
   02-base-components.rst
   03-rtems-apis.rst
   04-c-library.rst
   05-file-system.rst
   06-network-stack.rst
   07-component-complexity.rst
   08-rtems-initialization.rst
