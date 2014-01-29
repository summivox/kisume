###!
 * Kisume <%= pkg.version %>
 * <%= pkg.description %>
 * <%= pkg.homepage %>
###

# utilities
quote = (s) -> JSON.stringify s
unique = (a) -> ((last = x) for x in a when x != last)
strings = (a) -> (s for x in a when s = x?.toString())
san_func = (f) -> if f instanceof Function then f else ->
bailout = (cb, err) -> cb? err ; throw err

class Kisume
  VERSION: """<%= pkg.version %>"""
  constructor: do ->
    _ = (W, instanceName, opt, cb) ->
      if this not instanceof Kisume then return new Kisume W, instanceName, opt, cb
      if W?.top not instanceof Window
        bailout cb, Error 'Kisume: must be initialized on Window instance'

      instanceName = instanceName.replace(/[^\w]/g, '_')
      instanceNameTag = 'kisume_' + instanceName

      @instanceName = instanceName
      @options = opt || {}

      @_W = W
      @_D = W.document
      @_tran = {}
      @_init_cb = san_func cb
      @closure = do (instanceName) -> (script) -> "(function(ENV){#{script}})(#{instanceName}.ENV);"

      if @_D.head.dataset[instanceNameTag]
        bailout cb, Error 'Kisume: instance with same name already initialized on this window'
      else
        @_W.addEventListener 'message', @_listener
        script = "(#{KISUME_BOTTOM})('#{instanceName}');" # IIFE for bottom
        if @options.coffee
          # runtime published in window
          script = "#{COFFEE_RUNTIME};(function(){#{script};})();"
        else
          # runtime for bottom only
          script = "(function(){#{COFFEE_RUNTIME};#{script};})();"
        @inject script
        @_D.head.dataset[instanceNameTag] = @VERSION

    (W, instanceName, x...) ->
      switch x.length
        when 0, 1 then return _.call this, W, instanceName, {}, x...
        when 2 then return _.apply this, arguments

  inject: (script) ->
    el = @_D.createElement 'script'
    el.textContent = script
    @_D.head.appendChild el

  set: (ns, includes, o, cb) ->
    f = ''
    v = []
    for own name, x of o
      switch
        when x instanceof Function
          f += "#{ns}[#{quote name}] = (#{x});\n"
        when x instanceof Node
          # TODO
        else
          v.push {name, value: x}
    if f
      includes = unique (includes || []).concat(ns).sort()
      q = ''
      q += "var #{i} = ENV(#{quote i});\n" for i in includes
      @inject @closure "#{q};#{f};"
    @_Q_dn cb, {type: 'set', ns, v}

  get: (ns, names, cb) ->
    names = strings names
    @_Q_dn cb, {type: 'get', ns, names}

  # macro: run sync / async
  # NOTE: `_run` returns "->" function for proper binding
  _run = (async) ->
    # `this` <= kisumeInstance._ENV
    _iife = (f, args..., cb) ->
      n = @_Q_dn()
      @inject @closure "#{@instanceName}.iife[#{n}] = (#{f});"
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
        @_tran[n] = san_func cb
      if o?
        o._kisume_v1_instanceName = @instanceName
        o._kisume_v1_Q_dn = n
        @_W.postMessage o, @_W.location.origin
      return n

  _A_up: (n, o) ->
    cb = @_tran[n]
    switch o.type
      when 'init'
        @_init_cb.call this
      when 'set', 'get', 'run'
        if o.async
          cb o.err, o.rets...
        else
          cb o.err, o.ret
    delete @_tran[n]

  _listener: (e) =>
    if e.origin != window.location.origin ||
       !(o = e.data)? ||
       o._kisume_v1_instanceName != @instanceName then return
    switch
      # when (n = o._kisume_v1_Q_up)? then @_Q_up n, o
      when (n = o._kisume_v1_A_up)? then @_A_up n, o

KISUME_BOTTOM = (instanceName) ->
  ###! Kisume <%= pkg.version %> ###
  if window[instanceName] then return
  window[instanceName] = kisumeInstance = new class
    VERSION: """<%= pkg.version %>"""
    TRACE: """<%= TRACE %>"""
    constructor: ->
      @instanceName = instanceName

      @iife = {}
      @_tran = {}
      @_ENV = {}

      # NOTE: NOT declared in prototype to prevent sharing between instances
      @ENV = (x) =>
        if ns = x?.toString() then (@_ENV[ns] ||= {})
        else @_ENV

    _err: (e) -> switch
      when e instanceof Error
        # manually serialize
        do ->
          {name, message, stack} = e
          {name, message, stack}
      when e? then e
      else true

    _A_up: (n, o) ->
      o._kisume_v1_instanceName = @instanceName
      o._kisume_v1_A_up = n
      window.postMessage o, window.location.origin
      return

    _Q_dn: (n, o) ->
      try
        switch o.type
          when 'set'
            x = @ENV(o.ns)
            for {name, value} in o.v
              x[name] = value
            @_A_up n, {type: 'set'}
          when 'get'
            x = @ENV(o.ns)
            ret = {}
            for name in o.names
              ret[name] = do (v = x[name]) -> switch
                when v instanceof Function then v.toString()
                when v instanceof Node then 'Node' # TODO
                when v instanceof Error then @_err v
                else v
            @_A_up n, {type: 'get', ret}
          when 'run'
            if o.iife?
              f = @iife[o.iife]
              t = @_ENV
            else
              f = @ENV(o.ns)[o.name]
              t = @ENV(o.ns)
            if f not instanceof Function
              @_A_up n, {type: 'run', err: 'KISUME: function not found'}
            else if o.async
              f.call t, o.args..., (err, rets...) =>
                @_A_up n, {type: 'run', async: true, err, rets}
            else
              ret = f.apply t, o.args
              @_A_up n, {type: 'run', async: false, ret}
      catch e
        @_A_up n, {type: o.type, async: false, err: @_err(e)}
      return # _Q_dn

  window.addEventListener 'message', (e) ->
    if e.origin != window.location.origin ||
       !(o = e.data)? ||
       o._kisume_v1_instanceName != instanceName then return
    if kisumeInstance.TRACE == 'true'
      if o.err? then console.warn o
      else console.info o
    switch
      when (n = o._kisume_v1_Q_dn)? then kisumeInstance._Q_dn n, o
      # when (n = o._kisume_v1_A_dn)? then kisumeInstance._A_dn n, o

  # notify top: bottom init finished
  kisumeInstance._A_up 0, {
    _kisume_v1_instanceName: instanceName
    type: 'init'
  }

do (exports = if exports? then exports else this) ->
  exports.Kisume = Kisume
