# Pulse-Nim
An event system written in Nim! Does not work on the JS backend.

## Example
```nim
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
```