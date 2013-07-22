`
// ==UserScript==
// @name       kisume-test
// @namespace  http://github.com/smilekzs
// @version    0.1.0
// @match      *://github.com/smilekzs
// ==/UserScript==
// vim: set nowrap :

if (window.top != window.self) return;  //don't run on frames or iframes
`

document.addEventListener 'DOMContentLoaded', ->
  # kisume-ify a window (async)
  await kisume = Kisume window, defer()
 
  await kisume.set 'namespace', {
    var1: {x: 1, y: 2}
    var2: {x: -3, y: 4}
    func1: (a, b) -> {x: a.x + b.x, y: a.y + b.y}
    func2: (o) -> window.o = @namespace.func1(@namespace.var1, o)
    func3: (o, cb) -> setTimeout (=> cb null, o, @namespace.func2(o)), 1000
  }, defer(err)
  console.log err

  await kisume.run 'namespace', 'func1', {x: 100, y: 200}, {x: 300, y: -400}, defer(err, ret)
  console.log err
  console.log ret

  await kisume.runAsync 'namespace', 'func3', {x: 100, y: 100}, defer(err, ret1, ret2)
  console.log err
  console.log ret1
  console.log ret2

  await kisume.run (-> kisume.env.namespace.var2.x = -100), defer()
  kisume.get 'namespace', ['var2'], (err, o) ->
    {var2} = o
    console.log var2
