###!
https://github.com/smilekzs/kisume
Cross-sandbox-window utility library for userscript environments (Chrome, GreaseMonkey, ...)
!###

Kisume = do ->
  # inject script to bottom
  $ = (doc, script) ->
    el = doc.createElement 'script'
    el.textContent = script
    doc.head.appendChild el

  lib = ->
    ###!
    kisume: bottom library
    !###
    if window.kisume? then return
    window.kisume = kisume =
      # env: "ensure exist"
      env: (name) -> kisume.env[name] ||= {}

      _tran: {}

      _err: (e) -> switch
        when e instanceof Error
          # manually serialize
          do ->
            {name, message, stack} = e
            {name, message, stack}
        when e? then e
        else true

      _Q_up: do ->
        n = 0
        (cb, o) ->
          o._kisume_Q_up = ++n
          window.postMessage o, window.location.origin
          @_tran[n] = cb
          return
      _A_up: (n, o) ->
        o._kisume_A_up = n
        window.postMessage o, window.location.origin
        n

      _Q_dn: (n, o) ->
        try
          switch o.type
            when 'set'
              x = kisume.env(o.ns)
              for {name, value} in o.v
                x[name] = value
              @_A_up n, {type: 'set', err: null}
            when 'get'
              x = kisume.env(o.ns)
              ret = {}
              for name in o.names
                ret[name] = x[name]
              @_A_up n, {type: 'get', err: null, ret}
            when 'run'
              ret = kisume.env(o.ns)[o.name]?.apply kisume.env, o.args
              @_A_up n, {type: 'run', err: null, ret}
        catch e
          @_A_up n, {type: o.type, err: @_err(e)}

      _A_dn: (n, o) ->
        switch o.type
          when 'pub'
            null #TODO

    window.addEventListener 'message', (e) ->
      if e.origin != window.location.origin ||
         !(o = e.data)? then return
      switch
        when (n = o._kisume_Q_dn)? then kisume._Q_dn n, o
        when (n = o._kisume_A_dn)? then kisume._A_dn n, o

    # notify top: bottom init finished
    kisume._Q_up (->), {type: 'init'}

  class Kisume
    debug: true
    constructor: (W, cb) ->
      unless this instanceof Kisume then return new Kisume(W, cb)
      @W = W
      @D = W.document
      @_tran = {}
      @_init_cb = cb
      @W.addEventListener 'message', @_listener
      $ @D, "(#{lib})();"

    set: (ns, o, cb) ->
      # TODO: sanitize
      f = '' # func: metaprogrammed
      v = [] # var : posted
      for own name, x of o
        switch
          when x instanceof Function
            f += "o[#{JSON.stringify name}] = #{x};\n"
          when x instanceof Node
            #TODO
          else
            v.push {name, value: x}
      $ @D, "(function(o){#{f}})(window.kisume.env(#{JSON.stringify ns}));"
      @_Q_dn cb, {type: 'set', ns, v}

    get: (ns, names, cb) ->
      # TODO: sanitize
      @_Q_dn cb, {type: 'get', ns, names}

    run: do ->
      _func = (f, cb) ->
        n = @_Q_dn cb
        $ @D, """
          try {
            var ret = (#{f}).call(window.kisume.env);
            window.kisume._A_up(#{n}, {type: 'run', err: null, ret: ret});
          } catch(e) {
            window.kisume._A_up(#{n}, {type: 'run', err: window.kisume._err(e)});
          }
        """
      _script = (s, cb) ->
        _func.call this, "function(){;#{s};}", cb
      _env = (ns, name, args..., cb) ->
        @_Q_dn cb, {type: 'run', ns, name, args}

      # overload resolve
      (x, xs...) ->
        (switch xs.length
          when 0 then ->
          when 1
            {
              'function': _func
              'string': _script
            }[typeof x]
          else _env
        ).apply this, arguments

    _Q_dn: do ->
      n = 0
      (cb, o) ->
        @_tran[++n] = cb
        if o?
          o._kisume_Q_dn = n
          @W.postMessage o, @W.location.origin
        return n
    _A_dn: (n, o) ->
      o._kisume_A_dn = n
      @W.postMessage o, @W.location.origin
      n

    _Q_up: (n, o) ->
      switch o.type
        when 'init'
          @_init_cb this
        when 'pub'
          null

    _A_up: (n, o) ->
      cb = @_tran[n]
      switch o.type
        when 'set', 'get', 'run'
          cb? o.err, o.ret
      delete @_tran[n]

    _listener: (e) =>
      if e.origin != window.location.origin ||
         !(o = e.data)? then return
      if @debug then console.log o
      switch
        when (n = o._kisume_Q_up)? then @_Q_up n, o
        when (n = o._kisume_A_up)? then @_A_up n, o
