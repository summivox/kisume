# Kisume

![Kisume](http://images1.wikia.nocookie.net/__cb20091026154610/touhou/images/b/b0/Kisume.png)

Kisume is a javascript library (written in coffee-script) designed to free your
Userscript from the limitation of sandboxes in a safe yet convenient way.

The name comes from [Touhou 11](http://touhou.wikia.com/wiki/Kisume).

**NOTICE: Using mangler (e.g. `uglifyjs -m`) on coffee-script output (and
probably other compile-to-javascript languages) could cause Kisume to stop
working, due to language runtime library being mangled.**


## Features

* Zero runtime dependency
* Almost no impact on coding style
* Minimal pollution of global namespace (only `window.KISUME`)

The following environments are supported:

* Chrome plugin (content scripts)
* Chrome + TamperMonkey
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
console.log '===begin kisume test==='

await kisume.set 'namespace', [], {
  var1: {x: 1, y: 2}
  var2: {x: -3, y: 4}
  func1: (a, b) -> {x: a.x + b.x, y: a.y + b.y}
  func2: (o) -> window.o = @func1(@var1, o)
  func3: (o, cb) -> setTimeout (=> cb null, o, @func2(o)), 1000
}, defer(err)
console.assert !err?

await kisume.run 'namespace', 'func1', {x: 100, y: 200}, {x: 300, y: -400}, defer(err, ret)
console.assert !err?
console.assert ret.x == 400 && ret.y == -200

await kisume.runAsync 'namespace', 'func3', {x: 100, y: 100}, defer(err, ret1, ret2)
console.assert !err?
console.assert ret1.x == 100 && ret1.y == 100
console.assert ret2.x == 101 && ret2.y == 102

await kisume.run (-> @namespace.var2.x = -100), defer(err)
console.assert !err?

await kisume.get 'namespace', ['var2'], defer(err, {var2})
console.assert !err?
console.assert var2.x == -100 && var2.y == 4

console.log '===end kisume test==='
```
