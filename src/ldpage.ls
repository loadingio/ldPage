ldPage = (opt = {}) ->
  if opt.fetch => @_fetch = opt.fetch; delete opt.fetch
  @ <<< {
    evt-handler: {}, data: {},
    handle: {}, offset: 0, running: false, end: false
    # we use disabled to better semantic align with `running` and `end`
    disabled: (if opt.enabled? => !opt.enabled else false)
  }
  @opt = {
    boundary: 0, limit: 20, offset: 0, scroll-delay: 100, fetch-delay: 200, fetch-on-scroll: false
  } <<< opt
  @ <<< @opt{limit, offset}
  if @opt.host => @set-host that
  @

ldPage.prototype = Object.create(Object.prototype) <<< do
  # should be overwritten
  _fetch: -> new Promise (res, rej) -> return res {payload: []}
  toggle: (v) -> @disabled = if v? => !v else !@disabled
  on: (n, cb) -> @evt-handler.[][n].push cb
  fire: (n, ...v) -> for cb in (@evt-handler[n] or []) => cb.apply @, v
  reset: (opt = {}) ->
    for k,v of @handle => clearTimeout v
    @ <<< offset: 0, end: false
    if opt.data => @data = opt.data
  init: (opt) -> @reset opt
  fetchable: -> !(@disabled or @end or @running)
  is-end: -> @end
  set-host: (host) ->
    if !host => host = document.scrollingElement
    f = (e) ~> @on-scroll e
    if @host => @host.removeEventListener \scroll, f
    @host = (if typeof(host) == \string => document.querySelector(host) else host)
    if !@host => @host = null; return
    if @opt.fetch-on-scroll and !@opt.pivot => return @host.addEventListener \scroll, f
    if @opt.pivot =>
      if @obs => @obs.unobserve @opt.pivot
      update = (ns) ~>
        if !( ns.map(->it.isIntersecting).filter(->it).length and @fetchable! ) => return
        @fetch!then ~> @fire \scroll.fetch, it
      @obs = new IntersectionObserver update, {}
      @obs.observe @opt.pivot

  on-scroll: ->
    if !@fetchable! => return
    clearTimeout @handle.scroll
    # window doesn't have scrollHeight, scrollTop and clientHeight thus we fallback to scrollingElement
    h = if @host == window => document.scrollingElement else @host
    @handle.scroll = setTimeout (~>
      if h.scrollHeight - h.scrollTop - h.clientHeight > @opt.boundary => return
      if @fetchable! => @fetch!then ~> @fire \scroll.fetch, it
    ), @opt.scroll-delay

  set-loader: ->
  parse-result: -> it
  fetch: (opt={}) -> new Promise (res, rej) ~> # TODO clear res when clearTimeout is called
    if !@fetchable! => return res []
    if @handle.fetch => clearTimeout @handle.fetch
    @fire \fetching
    @handle.fetch = setTimeout (~>
      @running = true
      @_fetch!then (ret = []) ~>
        ret = @parse-result ret
        @running = false
        @offset += (ret.length or 0)
        @fire \fetch, ret
        if ret.length < @limit =>
          @end = true
          @fire (if !@offset => \empty else \finish)
        res ret
    ), (opt.delay or @opt.fetch-delay or 200)

if module? => module.exports = ldPage
else if window? => window.ldPage = ldPage
