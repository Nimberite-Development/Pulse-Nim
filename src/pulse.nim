## Here's a basic example of how to use Pulse!
runnableExamples:
  # This is NOT guaranteed to be threadsafe at any point, you must implement the appropriate measures yourself!
  type
    Meta = object
      name*: string

    Event = object
      typ*: string

  var eventHandler = newEventHandler[Meta]()

  eventHandler.registerEventType(Event)
  eventHandler.registerListener(Event) do (m: Meta, e: Event):
    echo m.name
    echo e.typ

  var meta = Meta(name: "Test")

  eventHandler.fire(meta, Event(typ: "test A"))
  eventHandler.fire(meta, Event(typ: "test B"))

import std/[
  asyncdispatch,
  strformat,
  tables,
  macros
]

type
  UnregisteredEventDefect* = object of Defect

  EventHandlerBase[T] = object of RootObj
    tbl: TableRef[pointer, seq[pointer]]

  EventHandler*[T] = object of EventHandlerBase[T]
  AsyncEventHandler*[T] = object of EventHandlerBase[T]

  EventHandlers[T] = AsyncEventHandler[T] | EventHandler[T]

  ListenerProc[T, R] = proc(o: T, p: R) {.nimcall.}
  AsyncListenerProc[T, R] = proc(o: T, p: R) {.async, nimcall.}

  ListenerProcs[T, R] = AsyncListenerProc[T, R] | ListenerProc[T, R]

proc newEventHandler*[T](): EventHandler[T] = EventHandler[T](tbl: newTable[pointer, seq[pointer]]())

proc newAsyncEventHandler*[T](): AsyncEventHandler[T] = AsyncEventHandler[T](tbl: newTable[pointer, seq[pointer]]())

macro validateProc[T](t: typedesc[T], r: typed) =
  ## Macro that validates inputted procs so that they're guaranteed to work.
  var n: NimNode

  if r.kind != nnkLambda:
    n = getImpl(r)

  else:
    n = r

  if n[3].len <= 2:
    error(&"`{r.repr}` must accept two arguments at minimum!", n[3][1])

  elif n[3].len > 3:
    error(&"`{r.repr}` must accept two arguments at most!", n[3][1])

  elif n[3][2][1].getImpl() != t.getImpl():
    error(&"`{r.repr}` must accept `{t}` but it accepts an incompatible type!", n[3][2][1])

  elif n[3][0].kind != nnkEmpty:
    if n[3][0][1][1].strVal == "Future":
      if n[3][0][1][2].strVal != "void":
        error(&"`{r.repr}` must have no return type!", n[3][0])

      else:
        return

    error(&"`{r.repr}` must have no return type!", n[3][0])

func registerEventType*[T](eh: var EventHandlers, t: typedesc[T]) =
  eh.tbl[default(t).getTypeInfo()] = newSeq[pointer]()

func internal_registerListener[T, R](eh: var EventHandlers[T], t: typedesc[R], l: ListenerProcs[T, R]) =
  eh.tbl[default(t).getTypeInfo()].add(cast[pointer](l))

template registerListener*[T, R](eh: EventHandler[T], t: typedesc[R], l: ListenerProc[T, R]) =
  validateProc(t, l)

  if not eh.tbl.hasKey(default(t).getTypeInfo()):
    raise newException(UnregisteredEventDefect, "Event type not registered!")

  eh.internal_registerListener(t, l)

template registerListener*[T, R](eh: AsyncEventHandler[T], t: typedesc[R], l: AsyncListenerProc[T, R]) =
  validateProc(t, l)
  eh.internal_registerListener(t, l)

proc fire*[T, R](eh: EventHandler[T], o: T, p: R) =
  for handler in eh.tbl[p.getTypeInfo]:
    cast[ListenerProc[T, R]](handler)(o, p)

proc fire*[T, R](eh: AsyncEventHandler[T], o: T, p: R) {.async.} =
  for handler in eh.tbl[p.getTypeInfo]:
    asyncCheck cast[AsyncListenerProc[T, R]](handler)(o, p)