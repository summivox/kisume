###! https://github.com/smilekzs/kisume ###

$ = (doc, script) ->
  el = doc.createElement 'script'
  el.textContent = script
  doc.head.appendChild el

class Kisume
  VERSION: """<%= pkg.version %>"""
  constructor: (W, cb) ->
    unless this instanceof Kisume then return new Kisume(W, cb)
    @W = W
    @D = W.document
    @_tran = {}
    @_init_cb = cb
    @W.addEventListener 'message', @_listener
    if !(@D.body.dataset['kisume'])?
      $ @D, "#{COFFEE_RUNTIME};(#{KISUME_BOTTOM})();"
      @D.body.dataset['kisume'] = true

  set: (ns, requires, o, cb) ->
    # variables: postMessage'd
    # functions: metaprogrammed:
    #   do (e = KISUME.env) ->
    #     require_i = e.require_i
    #     o = e('ns')
    #     o['name'] = (...) -> ...

    f = ''
    v = []
    for own name, x of o
      switch
        when x instanceof Function
          f += "o[#{JSON.stringify name}] = (#{x});\n"
        when x instanceof Node
          #TODO
        else
          v.push {name, value: x}
    if f
      q = ''
      q += "var #{r} = e(#{JSON.stringify r});\n" for r in requires
      $ @D, script = """
        (function(e){
        o = e(#{JSON.stringify ns});
        #{q};
        #{f};
        })(KISUME.env);
      """
    @_Q_dn cb, {type: 'set', ns, v}

  get: (ns, names, cb) ->
    # TODO: sanitize
    @_Q_dn cb, {type: 'get', ns, names}

  # macro: run sync / async
  # NOTE: `_run` returns "->" function for proper binding
  _run = (async) ->
    # `this` <= KISUME.env
    _iife = (f, args..., cb) ->
      n = @_Q_dn()
      $ @D, "window.KISUME.iife[#{n}] = (#{f});"
      @_Q_dn cb, {type: 'run', async, iife: n, args}

    # `this` <= namespace
    _bound = (ns, name, args..., cb) ->
      @_Q_dn cb, {type: 'run', async, ns, name, args}

    (x, xs...) ->
      (switch typeof x
        when 'function' then _iife
        when 'string' then _bound
        else ->
      ).apply this, arguments

  run: _run false
  runAsync: _run true

  _Q_dn: do ->
    n = 0
    (cb, o) ->
      ++n
      if cb
        @_tran[n] = cb
      if o?
        o._kisume_Q_dn = n
        @W.postMessage o, @W.location.origin
      return n

  _A_up: (n, o) ->
    cb = @_tran[n]
    switch o.type
      when 'init'
        @_init_cb this
      when 'set', 'get', 'run'
        if o.async
          cb? o.err, o.rets...
        else
          cb? o.err, o.ret
    delete @_tran[n]

  _listener: (e) =>
    if e.origin != window.location.origin ||
       !(o = e.data)? then return
    switch
      # when (n = o._kisume_Q_up)? then @_Q_up n, o
      when (n = o._kisume_A_up)? then @_A_up n, o

KISUME_BOTTOM = ->
  ###! https://github.com/smilekzs/kisume ###
  if window.KISUME? then return
  window.KISUME = KISUME = new class
    VERSION: """<%= pkg.version %>"""
    TRACE: """<%= TRACE %>"""
    constructor: ->
      @iife = {}
      @_tran = {}
      @env = (name) => @env[name] ||= {}

    _err: (e) -> switch
      when e instanceof Error
        # manually serialize
        do ->
          {name, message, stack} = e
          {name, message, stack}
      when e? then e
      else true

    _A_up: (n, o) ->
      o._kisume_A_up = n
      window.postMessage o, window.location.origin
      return

    _Q_dn: (n, o) ->
      try
        switch o.type
          when 'set'
            x = @env(o.ns)
            for {name, value} in o.v
              x[name] = value
            @_A_up n, {type: 'set'}
          when 'get'
            x = @env(o.ns)
            ret = {}
            for name in o.names
              # TODO: handle data types
              ret[name] = do (v = x[name]) -> switch
                when v instanceof Function
                  'Function'
                when v instanceof Node
                  'Node'
                when v instanceof Error
                  @_err v
                else v
            @_A_up n, {type: 'get', ret}
          when 'run'
            if o.iife?
              f = @iife[o.iife]
              t = @env
            else
              f = @env(o.ns)[o.name]
              t = @env(o.ns)
            if !f
              @_A_up n, {type: 'run', err: true}
            else if o.async
              f?.call t, o.args..., (err, rets...) =>
                @_A_up n, {type: 'run', async: true, err, rets}
            else
              ret = f?.apply t, o.args
              @_A_up n, {type: 'run', async: false, ret}
      catch e
        @_A_up n, {type: o.type, async: false, err: @_err(e)}
      return # _Q_dn

  window.addEventListener 'message', (e) ->
    if e.origin != window.location.origin ||
       !(o = e.data)? then return
    if KISUME.TRACE == 'true'
      if o.err? then console.warn o
      else console.info o
    switch
      when (n = o._kisume_Q_dn)? then KISUME._Q_dn n, o
      # when (n = o._kisume_A_dn)? then KISUME._A_dn n, o

  # notify top: bottom init finished
  KISUME._A_up 0, {type: 'init'}

do (exports = if exports? then exports else this) ->
  exports.Kisume = Kisume
