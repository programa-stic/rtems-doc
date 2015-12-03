.. _thread-management:

Administración de *Threads*
===========================

Un *thread* (hilo de ejecución) está representado por la estructura ``Thread_Control`` que hereda de (incluye a) ``Objects_Control``. En la documentación esta estructura es definida como *Thread Control Block* (TCB). Los atributos más importantes son:

.. code-block:: c
   :caption: cpukit/score/include/rtems/score/thread.h

    /**
     *  This structure defines the Thread Control Block (TCB).
     */
    struct Thread_Control_struct {
      /** This field is the object management structure for each thread. */
      Objects_Control          Object;
      /** This field is the current execution state of this thread. */
      States_Control           current_state;
      /** This field is the current priority state of this thread. */
      Priority_Control         current_priority;
      /** This field is the blocking information for this thread. */
      Thread_Wait_information  Wait;
      /** This field is the Watchdog used to manage thread delays and timeouts. */
      Watchdog_Control         Timer;
      /**
       * @brief The scheduler node of this thread for the real scheduler.
       */
      struct Scheduler_Node               *scheduler_node;
      /** This field contains the context of this thread. */
      Context_Control                       Registers;
    };

El atributo ``scheduler_node`` guarda información de *scheduling* (planificación de la ejecución) para ese *thread* en particular (mecanísmo descripto en :ref:`Planificación de Threads <thread-scheduling>`), en el caso de DPS (*Deterministic Priority Scheduler*, planificador determinístico en base a prioridad) tiene un puntero a la lista de *threads* correspondiente a su prioridad. ``Registers`` contiene el contexto del *thread* (valor de los registros), siendo dependiente de la arquitectura.


Inicialización
--------------

Se estudió la inicialización de los *threads* a traves de la API POSIX, particularmente la función ``pthread_create()``.

La inicialización de un *thread* se lleva a cabo mediante la función ``_Thread_Initialize``. A continuación se describen los pasos que realiza.

1. Se Inicializa el *Stack* del *thread*: El área de memoria se puede especificar por parámetro, o en caso de no especificarse, se reserva un área del *WorkSpace* de RTEMS mediante la función ``_Thread_Stack_Allocate``.

2. Se inicializa el TLS (*Thread-local Storage*): Aquí se guardan variables propias de este *thread* (locales a éste), que no se desea que se modifiquen por otros *threads*.

3. Se inicializa un *Watchdog timer*: En el caso de que el sistema de planifiación de ejecución use un algoritmo de tipo *bugdet* se utiliza el *watchdog* si no, se inicializa en ``NULL``.

4. Se inicializa el *Extension Area*: Este es el array de punteros a funciones (*hooks*) definidos por el usuario para ejecutarse durante los distintos eventos que pueden sucederle al *thread*.

5. Se asocia el *Scheduler*: Se asocia al *thread* el *scheduler* pasado como parámetro.

6. Se da de alta la información del *thread* en el *Scheduler* con ``_Scheduler_Node_initialize``. En el caso de DPS esto no tiene efecto.

7. Se establece la prioridad del *thread*.

8. Se inicializa las *Post-Switch actions* del thread: Estas son las acciones a tomar luego de hacer un cambio de contexto en el ``_Thread_Dispatch``.

9. Abre el objeto *thread* (agrega al objecto ``information`` al objeto ``thread``): Le establece el nombre y lo carga en la tabla local.

10. Se hace ``_User_extensions_Thread_create``: Este llama a la funcion asociada al evento *thread create* (creación) en las *user extensions* (extensiones definidas por el usuario), creadas anteriormente.


Comienzo
--------

El comienzo de un *thread* se realiza mediante la función ``_Thread_Start``. Los pasos realizados son los siguientes:

1. Se establece el *entry point* y el parámetro de entrada del *thread*, la primera función que este va a ejecutar.

2. Inicialización del entorno del *thread*: Lo más importante de esta etapa es la inicialización del contexto de un *thread*: *registros* (``Context_Control``), *stack pointer*, *stack size*, *thread local storage* e *interrupciones** (si prende interrupciones o no). Para esto, se invoca a la función ``_CPU_Context_Initialize`` provista por el módulo del CPU que corresponda (por ejempo, i386). El contexto es dependiente de la arquitectura subyacente.

3. Se establece el estado del *thread*: Se pasa del estado ``STATES_DORMANT`` (dormido) a ``STATES_READY`` (listo).

4. Se hace ``_User_extensions_Thread_start``: Este llama a la funcion asociada al evento *thread start* (inicio del *thread*) en las extensiones definidas por el usuario.
