Misceláneos
===========

*Watchdog*
----------

Cada *thread* creado, instanciado en ``Thread_Control``, tiene el atributo:

.. code-block:: c

	/** This field is the Watchdog used to manage thread delays and timeouts. */
	Watchdog_Control         Timer;

El ``Watchdog_Control`` no desciende de ``Objects_Control`` pero tiene su propio ``Chain_Node`` para ser encadenado en una de las listas ``_Watchdog_Ticks_chain`` o ``_Watchdog_Ticks_chain`` que llaman al *watchdog* cada tick o cada segundo respectivamente.

La función ``_Watchdog_Tickle`` recorre estas listas y ejecuta las rutinas

.. code-block:: c

	/** This field is the function to invoke. */
	Watchdog_Service_routine_entry  routine;

registradas en esa lista. Esto sucede solo en el caso de que el estado del *wathcdog* sea ``WATCHDOG_ACTIVE``, los otros estados tienen funcionalidades soporte que no fueron estudiadas en profundidad.
