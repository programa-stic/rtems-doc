Componentes Básicos
===================

Objeto
------

Un "objeto" dentro de SuperCore es una estructura llamada ``<Objeto>_Control`` (por ejemplo, ``Heap_Control``). Este contiene toda la información para manejarlo y todas las funciones que operan sobre él.

RTEMS, a pesar de estar escrito en C, trabaja con un paradigma similar al de objetos. Existe un objeto base, ``Object``, del cual "heredan" el resto de los objetos del SO. A su vez, las distintas clases de objetos están subdivididas por las API que las utilizan, principalmente **Internal API**, **Classic API** y **POSIX API**.

En la terminología de objetos, la **clase** (el tipo) de un objeto se representa en la estructura ``Objects_Information``. En la inicialización del sistema (``rtems_initialize_data_structures``), se crea un tipo de esta estructura por cada clase de objeto, mediante la función ``_Objects_Initialize_information``. Básicamente, esta función carga los distintos valores de ``Objects_Information`` y agregan su dirección a la tabla general, que guarda todos los tipos de objetos existentes: ``_Objects_Information_table`` indexada por *API* y *Class*.

Por consistencia, definimos **tipo** en esta documentación a la clase como se la entiende en el paradigma de objetos (para distinguirla del término *clase* utilizado en el código de RTEMS) e **instancia** a un objeto instanciado de este tipo. Con este esquema, el término **Information** en RTEMS se traduce al tipo de un objeto, y **Control** a una instancia de ese tipo.

Una vez creado un tipo de objeto, pueden asignarse instancias del mismo, mediante la función ``_Objects_Allocate_unprotected`` que recibe como parámetro ``Objects_Information`` (la descripción del tipo de objeto). Esta función revisa la lista (*chain*) ``Inactive`` con las instancias *inactivas* (se entiende por esto, no utilizadas) ya creadas y devuelve la primera de la lista. En caso de no haber ninguna se crean nuevas con ``_Objects_Extend_information``.

.. note::

    Todos los archivos que están en ``cpukit/score/src`` tiene la misma estructura (salvo excepciones puntuales). Los nombres de archivos están formados de la siguiente manera: ``<objeto><funcionalidad>.c``, donde:

        * ``objeto``: Es el nombre del "objeto" definido en el archivo, por ejemplo, ``Heap``.

        * ``funcionalidad``: Es la funcionalidad (función o grupo de funciones afines) que se implementa en un determinado archivo, por ejemplo, ``allocate``.

    Por lo tanto, con el ejemplo anterior, el nombre sería ``heapallocate.c``.

    Además, también está el archivo ``<objeto>.c`` donde se define la función ``_<objeto>_Initialize`` que inicializa el objeto en cuestión (por ejemplo, ``_Heap_Initialize``).

    Por otro lado, en ``cpukit/score/include/rtems``, están los archivos ``<objeto>.h`` y ``<objeto>impl.h``. El primero tiene las definiciones de las estructuras involucradas en implementación del "objeto". El segundo tiene la declaración de las funciones que provee el módulo del objeto que define y la implementación de las funciones *inline*. También hay definiciones de estructuras complementarias.


Ejemplo
-------

A continuación se muestra un ejemplo, con los objetos *Mutex* de la API clásica de RTEMS, creados en la inicialización del OS, en ``rtems_initialize_data_structures``.

La tabla ``_Objects_Information_table`` indexa primero por API y luego por clase, los distintos tipos de objetos:

.. code-block:: c
   :caption: cpukit/score/include/rtems/score/objectimpl.h

	/**
	 *  The following is the list of information blocks per API for each object
	 *  class.  From the ID, we can go to one of these information blocks,
	 *  and obtain a pointer to the appropriate object control block.
	 */
	SCORE_EXTERN Objects_Information **_Objects_Information_table[OBJECTS_APIS_LAST + 1];

En la entrada de la tabla correspondiente a la API interna, se registra el *array* que almacenará los tipos de objetos de esta API:

.. code-block:: c
   :caption: cpukit/sapi/src/exinit.c

	Objects_Information *_Internal_Objects[ OBJECTS_INTERNAL_CLASSES_LAST + 1 ];

	...

	/*
	* Initialize the internal support API and allocator Mutex
	*/
	_Objects_Information_table[OBJECTS_INTERNAL_API] = _Internal_Objects;


La estructura ``_API_Mutex_Information`` guarda la información del tipo de objetos *Mutex*.

.. code-block:: c
   :caption: cpukit/score/src/apimutex.c

	static Objects_Information _API_Mutex_Information;

La función ``_API_Mutex_Initialization`` inicializa esta estructura con la información del tipo del objeto:

.. code-block:: c
   :caption: cpukit/score/src/apimutex.c

	void _API_Mutex_Initialization(
	  uint32_t maximum_mutexes
	)
	{
	  _Objects_Initialize_information(
	    &_API_Mutex_Information,     /* object information table */
	    OBJECTS_INTERNAL_API,        /* object API */
	    OBJECTS_INTERNAL_MUTEXES,    /* object class */
	    maximum_mutexes,             /* maximum objects of this class */
	    sizeof( API_Mutex_Control ), /* size of this object's control block */
	    false,                       /* true if the name is a string */
	    0                            /* maximum length of an object name */
	  );
	}

Que la registrará en la tabla correspondiente, en ese caso, ``OBJECTS_INTERNAL_MUTEXES``

.. code-block:: c
   :caption: Resumen del efecto de la función ``_Objects_Initialize_information``

	_Objects_Information_table[ OBJECTS_INTERNAL_API ][ OBJECTS_INTERNAL_MUTEXES ] =
		&_API_Mutex_Information;

Una vez cargada la información para el tipo de objeto *Mutex*, podrán reservarse instancias de este tipo de objeto:

.. code-block:: c
   :caption: cpukit/score/src/apimutex.c

	mutex = (API_Mutex_Control *)
	  _Objects_Allocate_unprotected( &_API_Mutex_Information );

Esta función tomará la primera instancia *inactiva*, de ser inexistente (NULL) creará nuevas instancias mediante ``_Objects_Extend_information``.

La instancia obtenida será cargada con la información del objeto mediante la función:

.. code-block:: c
   :caption: cpukit/score/src/apimutex.c

	_Objects_Open_u32( &_API_Mutex_Information, &mutex->Object, 1 );

Esta función asigna el nombre al objeto y guarda una referencia en la tabla local.

La herencia se implementa insertando al principio del objeto ``Mutex``, el objeto "padre", ``Objects_Control``, que guarda la información básica del objeto.

.. code-block:: c
   :caption: cpukit/score/include/rtems/score/apimutex.h

	/**
	 * @brief Control block used to manage each API mutex.
	 */
	typedef struct {
	  /**
	   * @brief Allows each API Mutex to be a full-fledged RTEMS object.
	   */
	  Objects_Control Object;

	 ...

	} API_Mutex_Control;

Cada tipo de objeto guarda en su información el tamaño de una instancia:

.. code-block:: c
   :caption: cpukit/score/include/rtems/score/objectimpl.h

	/** This is the size in bytes of each object instance. */
	size_t            size;

Este tamaño puede ser mayor al de ``Objects_Control``, por los datos extra agregados por el "hijo". Al crear instancias de cada objeto, en ``_Objects_Extend_information`` y al asignar el tamaño de estas instancias, se pide este tamaño. Por eso, el ``Objects_Control`` retornado por ``_Objects_Allocate_unprotected`` puede ser convertido al tipo de objeto correspondiente (``API_Mutex_Control`` en el ejemplo presentado, mayor a ``Objects_Control``). Según el contexto el objeto puede manipularse como el ``Object`` padre, o como el objeto especializado (hijo).

Objetos Definidos
-----------------

A continuación se listan los objetos definidos dentro de SuperCore por categoría:

* Sincronización: CORE Mutex, CORE Barrier, CORE RWLock, CORE Semaphore, CORE Spinlock
* Threads: Thread, Thread Queue
* Scheduling: Scheluder
* Administración de Memoria: Heap, Protected Heap
* Auxiliares: Chain, FreeChain, Object, RBTree
* SMP: SMP Barrier
* Misceláneos: API Extension, API Mutex, CORE Message Queue, CORE TOD (Time Of Day), CPU Set [No está terminado], ISR, MPCI (Multiprocessing Communications Interface), Per CPU, State Control
