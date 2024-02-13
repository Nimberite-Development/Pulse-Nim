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
  strformat,
  tables,
  macros
]

when not defined(js):
  import std/asyncdispatch

type
  UnregisteredEventDefect* = object of Defect
  AlreadyRegisteredEventDefect* = object of Defect

  EventHandlerBase[T] = object of RootObj
    tbl: TableRef[TypeInfo, seq[pointer]]

  EventHandler*[T] = object of EventHandlerBase[T]

  ListenerProc[T, R] = proc(o: T, p: R) {.nimcall.}

  TypeInfo = distinct int

func `==`*(a, b: TypeInfo): bool {.borrow.}

proc newEventHandler*[T](): EventHandler[T] = EventHandler[T](tbl: newTable[TypeInfo, seq[pointer]]())

when not defined(js):
  type
    AsyncEventHandler*[T] = object of EventHandlerBase[T]

    EventHandlers[T] = AsyncEventHandler[T] | EventHandler[T]

    AsyncListenerProc[T, R] = proc(o: T, p: R) {.async, nimcall.}

    ListenerProcs[T, R] = AsyncListenerProc[T, R] | ListenerProc[T, R]

  proc newAsyncEventHandler*[T](): AsyncEventHandler[T] = AsyncEventHandler[T](tbl: newTable[TypeInfo, seq[pointer]]())

  template getTInfo(t: typedesc): TypeInfo =
    cast[TypeInfo](default(t).getTypeInfo)

else:
  type
    EventHandlers[T] = EventHandler[T]

    ListenerProcs[T, R] = ListenerProc[T, R]

  var counter = 0

  proc getTInfo(_: typedesc): TypeInfo =
    let id {.global.} = counter
    once:
      inc counter
    TypeInfo(id)

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

proc registerEventType*[T](eh: var EventHandlers, t: typedesc[T]) =
  if eh.tbl.hasKey(getTInfo(t)):
    raise newException(AlreadyRegisteredEventDefect, "Event already registered!")

  eh.tbl[getTInfo(t)] = newSeq[pointer]()

proc internal_registerListener[T, R](eh: var EventHandlers[T], t: typedesc[R], l: ListenerProcs[T, R]) =
  if not eh.tbl.hasKey(getTInfo(t)):
    raise newException(UnregisteredEventDefect, "Event type not registered!")

  eh.tbl[getTInfo(t)].add(cast[pointer](l))

template registerListener*[T, R](eh: EventHandler[T], t: typedesc[R], l: ListenerProc[T, R]) =
  validateProc(t, l)

  eh.internal_registerListener(t, l)

proc fire*[T, R](eh: EventHandler[T], o: T, p: R) =
  for handler in eh.tbl[typeof(p).getTInfo()]:
    when not defined(js):
      cast[ListenerProc[T, R]](handler)(o, p)

    else:
      {.error: "JS backend is not functional! Do not use!".}

when not defined(js):
  template registerListener*[T, R](eh: AsyncEventHandler[T], t: typedesc[R], l: AsyncListenerProc[T, R]) =
    validateProc(t, l)

    eh.internal_registerListener(t, l)

  proc fire*[T, R](eh: AsyncEventHandler[T], o: T, p: R) {.async.} =
    for handler in eh.tbl[typeof(p).getTInfo()]:
      asyncCheck cast[AsyncListenerProc[T, R]](handler)(o, p)
