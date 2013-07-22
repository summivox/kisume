# Kisume

Kisume is a javascript library (written in coffee-script) designed to free your
Userscript from the limitation of sandboxes in a safe yet convenient way.

**NOTICE: Using mangler (e.g. `uglifyjs -m`) on coffee-script output (and
probably other compile-to-javascript languages) could cause Kisume to stop
working, due to language runtime library being mangled.**


## Features

* Zero runtime dependency
* Almost no impact on coding style
* Minimal pollution of global namespace (only `window.KISUME`)


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


## Compatibility

Kisume works in the following userscript environments:

* Chrome plugin (content scripts)
* Chrome + TamperMonkey
* Firefox + GreaseMonkey
