# Kisume

![Kisume](http://images1.wikia.nocookie.net/__cb20091026154610/touhou/images/b/b0/Kisume.png)

**Kisume** (pronounced: kee-ss-may) is a library written in
[coffee-script][coffee] for cross-browser userscripting that works around the
limitation of sandboxes using only standard DOM manipulation, while featuring
a clean and DRY interface.

The name (and mascot) comes from the [Touhou Project](http://touhou.wikia.com/wiki/Kisume).

**NOTE: Using mangler (e.g. `uglifyjs -m`) on coffee-script output (and
probably other compile-to-javascript languages) could cause Kisume to stop
working, due to language runtime library being mangled.**


## Background

Being able to generate both a Chrome plugin and GreaseMonkey-compatible
userscript from the _same_ set of sources is an attractive idea, especially for
large userscripts offering rich functionality, where porting would be virtually
impossible should platform-specific features be relied upon.

However there are two often-needed features that happen to be in conflict:

* XHR(`GM_xmlhttpRequest`), available only in userscript's `window` (sandbox)
* Access to javascript environment of the page's "real" `window`

Either the script runs in the sandbox, which is an isolated namespace from the
real `window`; or it could be injected as a `<script>` tag into the page,
gaining access to the real `window` while losing access to cross-site XHR.

Prior to Chrome 27, the solution is to use `unsafeWindow` available in GM-like
environments. However [this is mostly broken now][unsafe], and the future
status of its support is unknown at the moment (TamperMonkey partially works
around this issue, but is still hacky).

**Kisume** uses an alternative approach: injecting `<script>` with carefully
constructed [IIFE][]s that does not inadvertently leak into real `window`, then
communicate using `window.postMessage`. Both are standard DOM manipulation.

The main drawback of this approach was overwhelming amount of boilerplate code
to make it work smoothly. However, **Kisume** has already taken care of this
tedious process for you -- all you need is to tell it what to run in the real
`window`, right from the sandbox, and it should _Just Work_.

[unsafe]: https://code.google.com/p/chromium/issues/detail?id=222652
[IIFE]: http://en.wikipedia.org/wiki/Immediately-invoked_function_expression


## Features

* True zero runtime dependency (only DOM manipulation needed)
* Trivially easy return value / error handling
* Minimal pollution of global `window` object:
    * coffee-script runtime library (e.g. `__slice` and friends)
    * `window.KISUME` encapsulates all
    * No pollution unless you run script that explicitly does so
* Cross-browser compatibility, with the following environments tested:
    * Chrome Stable + Chrome plugin content script
    * Chrome Stable + TamperMonkey Stable
    * Firefox + GreaseMonkey


## Build

Prerequisite: node.js

```sh
npm install --global grunt-cli
npm install
grunt
```

Use `dist/kisume.js` or `dist/kisume.min.js`.

### Options

```
--iced=true  :   Also include iced-coffee-script runtime.
--trace=true :   Enable postMessage tracing.
```


## Usage

All public methods of Kisume are asynchronous by nature, taking a
callback `(err, ...) -> ...` as the final argument, following node.js
convention.  This allows easy integration with async libraries, as well as
compile-to-javascript languages.

**NOTE:** Examples are in [iced-coffee-script][iced] for the convenience of
async handling, although the library itself is written in original
[coffee-script][coffee], compiled down to javascript.

[iced]: https://github.com/maxtaco/coffee-script
[coffee]: https://github.com/jashkenas/coffee-script

### Initialization

Include `kisume.js` into your userscript (preferrably using some build system).
Class `Kisume` is defined and exported _into the sandbox_ as `window.Kisume`.

You may initialize a Kisume instance from the sandbox on any Window instance
(`window` or `myIframeElement.contentWindow`):

```coffee
await kisume = Kisume window, defer()
```

The callback is fired when Kisume finishes initialization (on failure, nothing
happens). This means `window.KISUME` (notice the caps) is initialized in the
real `window`, and is ready to run scripts for you.

**NOTE:** Although `window` now refers to the sandbox, Kisume will correctly
initialize itself in the real `window`.

### Keep It Simple, Stupid

After initialization, we can directly use `kisume.run` to execute a function in
the target window (in an [IIFE][] fashion). Assuming `window.a == 3`, then:

```coffee
kisume.run ((b) -> window.a + b), 4, (err, ret) ->
  if err then console.error err
  else console.log ret
```

prints `7` onto the console.

**NOTE:**

* The first argument (function) is run in the real `window`, while the callback
  is run in the sandbox
* Arbitrary number of [**simple arguments**][post] may be passed
* Error, either due to argument passing, or during the execution of the
  function in the real `window`, is passed to the callback
* Return value of the function is passed to the callback as well

[post]: https://developer.mozilla.org/en-US/docs/Web/API/window.postMessage

### Getting Organized

In addition to running IIFEs, Kisume allows you to pass [simple objects][post]
and functions down to the real `window` domain and organize them into
_namespaces_.

A _namespace_ is a normal javascript object managed by `window.KISUME`.
Functions stored within a namespace are treated as methods of the namespace
object by default, so when called from the sandbox, `this` in function body
refers to its namespace object.

Additionally, you may easily refer to objects and functions stored in other
namespaces by declaring "included namespaces" or by using the special `ENV`
function to lookup any namespace by name.

Here is a concrete example:

```coffee
console.log '=== begin kisume test ==='
await kisume = Kisume window, defer()

await kisume.set 'namespace1', [], {
  var1: {x: 1, y: 2}
}, defer(err)
console.assert !err?

await kisume.set 'namespace2', ['namespace1'], {
  var1: {x: 11, y: 22}
  func1: (a, b) -> {x: a.x + b.x, y: a.y + b.y}
  func2: (o) -> window.o = @func1(namespace1.var1, o)
  func3: (o, cb) -> setTimeout (=> cb null, o, ENV('namespace2').func2(o)), 1000
}, defer(err)
console.assert !err?

await kisume.run 'namespace2', 'func1', {x: 100, y: 200}, {x: 300, y: -400}, defer(err, ret)
console.assert !err?
console.assert ret.x == 400 && ret.y == -200

await kisume.runAsync 'namespace2', 'func3', {x: 100, y: 100}, defer(err, ret1, ret2)
console.assert !err?
console.assert ret1.x == 100 && ret1.y == 100
console.assert ret2.x == 101 && ret2.y == 102

await kisume.run (-> @namespace2.var1.x = -100), defer(err)
console.assert !err?

await kisume.run (-> window.o), defer(err, ret)
console.assert !err?
console.assert ret.x == 101 && ret.y == 102

await kisume.get 'namespace2', ['var1'], defer(err, {var1})
console.assert !err?
console.assert var1.x == -100 && var1.y == 22

console.log '=== end kisume test ==='
```

#### `.set('ns', ['ns1', 'ns2'...], {name: func/obj}, cb)`

Attempts to dump functions and objects within `o` into namespace `ns`, with the
listed namespaces `ns1`, `ns2`... visible to said functions ("imported" into
scope)

**NOTE:**

* Name of a namespace must be a valid javascript identifier
* Objects and functions within the same namespace can be accessed using `this`
  (e.g. `@func1` as in `func2`)
* Included namespaces can be used directly in the function as if they're global
  objects (e.g. `namespace1.var1` as in `func2`)
* `ENV('namespace2')` provides a way to lookup other namespaces even if they're
  not explicitly included (e.g. `func3`), similar to `require()` in node.js
* To dump a whole simple object with methods: `.set('obj', [], obj, cb)`

#### `.{run | runAsync}({func | 'ns', 'name'}, args..., cb)`

Call a function in real `window`. Comes in 4 overloaded flavors:

* A/synchronous:
    * `run`:
        * Equivalent to `ret = f(args...)`
        * `cb(undefined, ret)` on function return
    * `runAsync`:
        * Equivalent to `f(args..., (err, rets) -> ...)`
        * `cb(err, rets...)` on async complete
* Function being called:
    * `func`: [IIFE][]. The function will be transferred to real `window`, then
      called as a method of the _parent object_ of all namespaces (e.g. first
      IIFE in above example).
    * `ns, name`: calls function stored in a namespace as its method.

**NOTE:**

* Error in argument passing / function throw will immediately invoke `cb(err)`
* `ENV('namespace')` is always available to the function
* `runAsync`: function should callback at most once

#### `.get(ns, [name1, name2, ...], cb)`

Attempts to read objects stored within the namespace.

* `cb(err)` on error
* `cb(undefined, {name1: obj1, name2: obj2, ...})` invoked on success

### Access `ENV('namespace')` from real `window`

`ENV` is an alias for `window.KISUME.ENV` in the real `window` visible to
functions managed by Kisume. All namespaces can be accessed by code in real
`window` through this interface.


## License

See `LICENSE`.
