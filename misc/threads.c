/*
 *  COPYRIGHT (c) 1989-2012.
 *  On-Line Applications Research Corporation (OAR).
 *
 *  The license and distribution terms for this file may be
 *  found in the file LICENSE in this distribution or at
 *  http://www.rtems.com/license/LICENSE.
 */

#ifdef HAVE_CONFIG_H
#include "config.h"
#endif

#include <bsp.h> /* for device driver prototypes */

#include <stdio.h>
#include <stdlib.h>

/* forward declarations to avoid warnings */
rtems_task Init(rtems_task_argument argument);

#include <pthread.h>

void* ThreadFn(void* argument);

void* Thread_1(void* argument);
void* Thread_2(void* argument);
void* Thread_3(void* argument);

void*
ThreadFn(
  void* argument
)
{
  unsigned int id = (unsigned int) argument;
  unsigned int i = 0;

  while(i++ < 1000000) {
    printf( "Hello Mundo %d!\n", id );
  }

  pthread_exit( NULL );

  return NULL;
}

void*
Thread_1(
  void* argument
)
{
  unsigned int i = 0;

  while(i++ < 1000000) {
    printf( "Hello Mundo 1!\n" );
  }

  pthread_exit( NULL );

  return NULL;
}

void*
Thread_2(
  void* argument
)
{
  unsigned int i = 0;

  while(i++ < 1000000) {
    printf( "Hello Mundo 2!\n" );
  }

  pthread_exit( NULL );

  return NULL;
}

void*
Thread_3(
  void* argument
)
{
  unsigned int i = 0;

  while(i++ < 1000000) {
    printf( "Hello Mundo 3!\n" );
  }

  pthread_exit( NULL );

  return NULL;
}

rtems_task Init(
  rtems_task_argument ignored
)
{
  printf( "\n\n*** HELLO WORLD TEST (THREADS) ***\n" );

  pthread_t Thread_id_1;
  pthread_t Thread_id_2;
  pthread_t Thread_id_3;

  pthread_attr_t attr;
  pthread_attr_init(&attr);
  pthread_attr_setinheritsched(&attr, PTHREAD_EXPLICIT_SCHED);
  pthread_attr_setschedpolicy(&attr, SCHED_RR);

  pthread_create(&Thread_id_1, &attr, ThreadFn, (void *) 1);
  pthread_create(&Thread_id_2, &attr, ThreadFn, (void *) 2);
  pthread_create(&Thread_id_3, &attr, ThreadFn, (void *) 3);

  if(pthread_join(Thread_id_3, NULL)) {
    fprintf(stderr, "Error joining thread 1\n");
    return;
  }

  if(pthread_join(Thread_id_2, NULL)) {
    fprintf(stderr, "Error joining thread 2\n");
    return;
  }

  if(pthread_join(Thread_id_1, NULL)) {
    fprintf(stderr, "Error joining thread 3\n");
    return;
  }

  printf( "*** END OF HELLO WORLD TEST (THREADS) ***\n" );

  exit( 0 );
}

#define CONFIGURE_MAXIMUM_POSIX_THREADS     10

#define CONFIGURE_APPLICATION_NEEDS_CLOCK_DRIVER

#define CONFIGURE_MICROSECONDS_PER_TICK   1000
#define CONFIGURE_TICKS_PER_TIMESLICE       50

#define CONFIGURE_APPLICATION_NEEDS_CONSOLE_DRIVER

#define CONFIGURE_MAXIMUM_TASKS            10
#define CONFIGURE_USE_DEVFS_AS_BASE_FILESYSTEM

#define CONFIGURE_RTEMS_INIT_TASKS_TABLE

#define CONFIGURE_INIT
#include <rtems/confdefs.h>
