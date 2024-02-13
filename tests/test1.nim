# This is just an example to get you started. You may wish to put all of your
# tests into a single file, or separate them into multiple `test1`, `test2`
# etc. files (better names are recommended, just make sure the name starts with
# the letter 't').
#
# To run these tests, simply execute `nimble test`.

import std/unittest

import pulse

type
  A = object
  B = ref object

test "Sync Events":
  var a = newEventHandler[A]()

  a.registerEventType(A)
  a.registerEventType(B)
  a.registerEventType(string)

  a.registerListener(A) do (a: A, b: A):
    echo "A"

  a.registerListener(B) do (a: A, b: B):
    echo "B"

  a.registerListener(string) do (a: A, b: string):
    echo b

  a.fire(A(), A())
  a.fire(A(), B())
  a.fire(A(), "Hello, World!")

when not defined(js):
  import std/asyncdispatch

  test "Async Events":
    var a = newAsyncEventHandler[A]()

    a.registerEventType(A)
    a.registerEventType(B)
    a.registerEventType(string)

    a.registerListener(A) do (a: A, b: A) {.async.}:
      await sleepAsync(100)
      echo "A"

    a.registerListener(B) do (a: A, b: B) {.async.}:
      echo "B"

    a.registerListener(string) do (a: A, b: string) {.async.}:
      echo b

    proc main() {.async.} =
      asyncCheck a.fire(A(), A())
      asyncCheck a.fire(A(), B())
      asyncCheck a.fire(A(), "Hello, World!")
      await sleepAsync(110)

    waitFor main()