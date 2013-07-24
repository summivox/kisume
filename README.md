# Kisume

![Kisume](http://images1.wikia.nocookie.net/__cb20091026154610/touhou/images/b/b0/Kisume.png)

**Kisume** (pronounced: kee-ss-may) is a library written in
[coffee-script][coffee] for cross-browser userscripting that works around the
limitation of sandboxes using only standard DOM manipulation, while featuring a
clean, node.js-inspired interface.

The name (and mascot) comes from the [Touhou Project](http://touhou.wikia.com/wiki/Kisume).

Some examples below are written in [iced-coffee-script][iced], a dialect of
[coffee-script][coffee] with convenient async handling.

**CAUTION:** Kisume library should _not_ be passed through any kind of manglers
(e.g. `uglifyjs -m`), either directly or indirectly (after concatenation).
`dist/kisume.min.js` should be used instead. Even if you really have to mangle,
you should blacklist all coffee-script reserved words (`__slice` and friends).

[iced]: https://github.com/maxtaco/coffee-script
[coffee]: https://github.com/jashkenas/coffee-script


## Build

Prerequisite: node.js, npm

```sh
npm install --global grunt-cli
npm install
grunt
```

Then include `dist/kisume.js` or `dist/kisume.min.js` into your userscript.

Extra flags that you may pass to `grunt`:

```
--iced=true  :   Also include iced-coffee-script runtime.
--trace=true :   Enable postMessage tracing.
```


## TL;DR

If this script was executed in target page:

```javascript
/*...*/
window.a = 20;
/*...*/
```

And you put this in your userscript source (run after page script execution):

```coffee
window.kisume = Kisume window, {coffee: true}, (err) ->
  if err
    console.error err
    return
  @run ((b) -> window.a + b), 22, (err, ret) ->
    if err then console.error err
    else console.log ret
```

`42` should be printed.

Notice the first argument of `@run` has access to page's `window`, as well as
[simple arguments][obj] from the sandbox.

[obj]: https://developer.mozilla.org/en-US/docs/Web/Guide/DOM/The_structured_clone_algorithm


## Background

Being able to generate both a Chrome plugin and GreaseMonkey-compatible
userscript from the _same_ set of sources is an attractive idea, especially for
large userscripts offering rich functionality, where porting would be virtually
impossible should platform-specific features be heavily relied upon.

However there are two often-needed features that happen to be in conflict:

* XHR(`GM_xmlhttpRequest`), available only in userscript's `window` (sandbox)
* Access to javascript environment of the page's "real" `window`

Either the script runs in the sandbox, which is an isolated namespace from the
target window; or it could be injected as a `<script>` tag into the page,
gaining access to the target window while losing access to cross-site XHR.

Prior to Chrome 27, the solution is to use `unsafeWindow` available in GM-like
environments. [However this is mostly broken now][unsafe], and the future
status of its support is unknown at the moment ([TamperMonkey partially works
around this issue, as a beta feature, though][TM404]).

There is an alternative approach: injecting `<script>` tag into target with
[IIFE][]s so that nothing inadvertently leaks into target window, then bridge
the gap using `window.postMessage`. Both are standard DOM manipulation. The
main drawback of this approach was overwhelming amount of boilerplate code to
make it work reliably and efficiently.

Kisume takes this approach, but instead takes care of this tedious process for
you -- all you need is to tell it what to run in the target window, right from
the sandbox, and it should _Just Work_.

[unsafe]: https://code.google.com/p/chromium/issues/detail?id=222652
[IIFE]: http://en.wikipedia.org/wiki/Immediately-invoked_function_expression
[TM404]: http://tampermonkey.net/faq.php#Q404


## Features

* True zero runtime dependency (only DOM manipulation needed)
* Trivially easy return value / error handling
* Minimal pollution of global `window` object:
    * `window.KISUME`
    * coffee-script runtime library (`__slice` and friends) _on your request_
    * Does not add anything else to `window` unless your script does so
* Cross-browser compatibility, with the following environments tested:
    * Chrome Stable + Chrome plugin content script
    * Chrome Stable + TamperMonkey Stable
    * Firefox + GreaseMonkey


## Usage

All public methods of Kisume are asynchronous by nature, taking a
callback `(err, ...) -> ...` as the final argument, following node.js
convention.  This allows easy integration with async libraries, as well as
compile-to-javascript languages.

### Initialization

Include `kisume.js` into your userscript (preferrably using some build system).
Class `Kisume` is defined and exported _into the sandbox_ as `window.Kisume`.

#### `Kisume(W, options, cb)`

Initialize Kisume instance on DOM Window instance `W` (can be `window` or
`iframeElem.contentWindow`). Each window may only be initialized once.
`cb(err)` is invoked on complete / error.

`options`: dictionary:

* `coffee`: When set to `true`, coffee-script runtime is exported to target
  window. This is often necessary if you're using coffee-script.

**NOTE:**

* If you're using another compile-to-javascript language, it's likely that
  you'll need to inject its runtime library into the target window as well.
  You can use `.inject(script)` for quick script tag injection.
* Regarding `Kisume(window, ...)`: Although `window` now refers to the sandbox,
  Kisume will correctly initialize itself in the target window.

### Keep It Simple, Stupid

After initialization, we can directly use `kisume.run` to execute a function in
the target window (in an [IIFE][] fashion), as demonstrated in above example.

### Getting Organized

In addition to running IIFEs, Kisume allows you to pass [simple objects][obj]
and functions down to the target window domain and organize them into
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

Call a function in target window. Comes in 4 overloaded flavors:

* A/synchronous:
    * `run`:
        * Equivalent to `ret = f(args...)`
        * `cb(undefined, ret)` on function return
    * `runAsync`:
        * Equivalent to `f(args..., (err, rets) -> ...)`
        * `cb(err, rets...)` on async complete
* Function being called:
    * `func`: [IIFE][]. The function will be transferred to target window, then
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

### Access `ENV('namespace')` from target window

`ENV` is an alias for `window.KISUME.ENV` in the target window visible to
functions managed by Kisume. All namespaces can be accessed by code in target
window through this interface.


## License

See `LICENSE`.
