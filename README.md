# Kisume

![Kisume](http://images1.wikia.nocookie.net/__cb20091026154610/touhou/images/b/b0/Kisume.png)

Kisume (pronounced: kee-ss-may) is a javascript library for cross-browser
userscripting that works around the limitation of sandboxes using only
standard DOM manipulation, while being extremely simple to use.

The name (and mascot) comes from the [Touhou Project](http://touhou.wikia.com/wiki/Kisume).

**NOTICE: Using mangler (e.g. `uglifyjs -m`) on coffee-script output (and
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

Kisume uses an alternative approach: injecting `<script>` with carefully
constructed [IIFE][]s that does not inadvertently leak into real `window`, then
communicate using `window.postMessage`. Both are standard DOM manipulation.
The main drawback of this approach was overwhelming amount of boilerplate code
to make it work smoothly; however, Kisume has taken care of that for you -- all
you need is to tell it what to run in the real `window`, right from the
sandbox, and it will Just Work (TM).

[unsafe]: https://code.google.com/p/chromium/issues/detail?id=222652
[IIFE]: http://en.wikipedia.org/wiki/Immediately-invoked_function_expression


## Features

* True zero runtime dependency (only DOM manipulation needed)
* Simple usage
* No inadvertent pollution of global namespace (only `window.KISUME`)

The following environments are tested:

* Chrome Stable + Chrome plugin content script
* Chrome Stable + TamperMonkey Stable
* Firefox + GreaseMonkey


## Build

```sh
npm install --global grunt-cli
npm install
grunt
```

Use `dist/kisume.js` or `dist/kisume.min.js`.

### Options

```
--iced  :   Also include iced-coffee-script runtime
--trace :   Enable postMessage tracing
```


## Usage

The library defines a single class `Kisume`, exported as `window.Kisume`.

(NOTE: under construction. See [renren-markdown][rrmd] for use-case.)
[rrmd]: https://github.com/smilekzs/renren-markdown

```coffee
await window.kisume = Kisume window, defer()
console.log '=== begin kisume test ==='

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

await kisume.get 'namespace2', ['var1'], defer(err, {var1})
console.assert !err?
console.assert var1.x == -100 && var1.y == 22

console.log '=== end kisume test ==='
```
