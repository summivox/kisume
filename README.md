# Kisume

Kisume is a javascript library (written in coffee-script) designed to free your
Userscript from the limitation of sandboxes in a safe yet convenient way, with
zero dependency on other libraries, and almost no impact on coding style. It
also tries not to inadvertently pollute the global namespace by managing data
and code under `window.kisume`.


## Usage

A single file `kisume.coffee` defines a single class `Kisume`, which is also
exported as `window.Kisume`.


## Example

See `test.coffee`.


## Compatibility

Kisume works in the following userscript environments:

* Chrome plugin (content scripts)
* Chrome + TamperMonkey
* Firefox + GreaseMonkey
