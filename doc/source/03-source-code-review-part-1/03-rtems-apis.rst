APIs de RTEMS
=============

RTEMS provee diferentes APIs para que las aplicaciones puedan
interactuar con el sistema, a saber: POSIX, Classic y SAPI.
Cada una de ellas brinda una funcionalidad particular.

POSIX
-----

A través de esta API, RTEMS implementa un subconjunto del standar
POSIX 1003b.1 que refiere a extensiones de Tiempo Real. Entre
los mecanísmos que define el standar están:

    * Planificación por Prioridades
    * Señales en Tiempo Real
    * Relojes y Temporizadores
    * Semáforos
    * Pasaje de Mensajes
    * Memoria Compartida
    * E/S Sincrónico y Asincrónico
    * Interfaz de Bloqueo de Memoria

Esta API tiene una estrecha y directa relación entre los componentes
que expone SuperCore.

Classic
-------

Implementada en el directorio ``${RTEMS_ROOT}/cpukit/rtems/``. Es la interfaz
presentada en el documento `"C User’s Guide" <http://docs.rtems.org/doc-current/share/rtems/html/c_user/>`_. Provee una serie de servicios
denominados **Managers**:

	* Initialization Manager
	* Task Manager
	* Interrupt Manager

	* Time
		* Clock Manager
		* Timer Manager

	* Communication and Synchronization
		* Semaphore Manager
		* Message Manager
		* Event Manager
		* Signal Manager

	* Memory Management
		* Partition Manager
		* Region Manager
		* Dual-Ported Memory Manager

	* I/O Manager
	* Fatal Error Manager
	* Rate Monotonic Manager
	* Barrier Manager
	* User Extensions Manager
	* Multiprocessing Manager

SAPI
----

Hay muy poca documentación al respecto de esta API. Se supone que es la API
de SuperCore, ubicada en ``${RTEMS_ROOT}/cpukit/sapi/``, según la
`"Development Environment Guide" <http://docs.rtems.org/doc-current/share/rtems/html/develenv/index.html>`_:
"*This directory contains the implementation
of RTEMS services which are required but beyond the realm of any
standardization efforts. It includes initialization, shutdown, and IO
services.*"

Según la implementación de ``Object``, en el código, esta API es referida como
``OBJECTS_INTERNAL_API`` en la ``_Objects_Information_table``, y contiene los
objetos del tipo ``OBJECTS_INTERNAL_THREADS`` y ``OBJECTS_INTERNAL_MUTEXES``.

Examinando el contenido del directorio parece implementar (al menos
parcialmente):

	* Chains
	* Debug Manager
	* Initialization Manager
	* Fatal Error Manager
	* IO Manager
	* Profiling API
	* Red-Black Tree Heap

Pero de todas formas presenta un gran acople con SuperCore, hay código C
situado en ``sapi`` que tiene su correspondiente *header file* en ``score`` y
viceversa. En términos prácticos para el código se lo puede pensar como una
extensión de SuperCore.
