

do -> class Yaku

	###*
	 * This class follows the [Promises/A+](https://promisesaplus.com) and
	 * [ES6](http://people.mozilla.org/~jorendorff/es6-draft.html#sec-promise-objects) spec
	 * with some extra helpers.
	 * @param  {Function} executor Function object with two arguments resolve and reject.
	 * The first argument fulfills the promise, the second argument rejects it.
	 * We can call these functions, once our operation is completed.
	###
	constructor: (executor) ->
		return if executor == $noop
		executor genSettler(@, $resolved), genSettler(@, $rejected)

	###*
	 * Appends fulfillment and rejection handlers to the promise,
	 * and returns a new promise resolving to the return value of the called handler.
	 * @param  {Function} onFulfilled Optional. Called when the Promise is resolved.
	 * @param  {Function} onRejected  Optional. Called when the Promise is rejected.
	 * @return {Yaku} It will return a new Yaku which will resolve or reject after
	 * the current Promise.
	###
	then: (onFulfilled, onRejected) ->
		addHandler @, (new Yaku $noop), onFulfilled, onRejected

# ********************** Private **********************

	###
	 * All static variable name will begin with `$`. Such as `$rejected`.
	 * @private
	###

	# ************************** Private Constant **************************

	###*
	 * These are some static symbolys.
	 * @private
	###
	$rejected = 0
	$resolved = 1
	$pending = 2

	# These are some symbols. They won't be used to store data.
	$circularError = 'circular promise resolution chain'

	# Default state
	_state: $pending

	###*
	 * The number of current promises that attach to this Yaku instance.
	 * @private
	###
	_pCount: 0

	###*
	 * `promise == parentPromise[promise._pIndex]`, it's true.
	 * @private
	###
	_pIndex: 0

	###*
	 * `then(_onParentFulfilled, _onParentRejected)` of parent promise.
	 * @private
	###
	_onParentFulfilled: undefined
	_onParentRejected: undefined

	# *************************** Promise Hepers ****************************

	###*
	 * Link the promise1 to the promise2.
	 * @private
	 * @param {Yaku} p1
	 * @param {Yaku} p2
	 * @param {Function} onFulfilled
	 * @param {Function} onRejected
	###
	addHandler = (p1, p2, onFulfilled, onRejected) ->
		if typeof onFulfilled == $function
			p2._onParentFulfilled = onFulfilled
		if typeof onRejected == $function
			p2._onParentRejected = onRejected

		if p1._state == $pending
			p1[p1._hCount] = p2
			p2._pIndex = p1._hCount++
		else
			if getHandlerByState(p1._state, p2) == undefined
				scheduleHandler p1, p2
			else
				settlePromise p2, p1._state, p1._value

		p2

	getHandlerByState = (state, p2) ->
		if state then p2._onParentFulfilled else p2._onParentRejected

	###*
	 * Resolve the value returned by onFulfilled or onRejected.
	 * @private
	 * @param {Yaku} p1
	 * @param {Yaku} p2
	###
	scheduleHandler = genScheduler 1000, (p1, p2) ->
		release p1, p2._pIndex

		x = genTryCatcher(callHanler) p1, p2
		if x == $tryErr
			settlePromise p2, $rejected, x.e
			return

		# Prevent circular chain.
		if x == p2 and x
			rejector = p2._onParentRejected
			if rejector
				rejector new TypeError $circularError
			return

		settleValue p2, x

		return

	###*
	 * Try to get return value of `onFulfilled` or `onRejected`.
	 * @private
	 * @param {Yaku} p1
	 * @param {Yaku} p2
	 * @return {Any}
	###
	callHanler = (p1, p2) ->
		getHandlerByState(p1._state, p2) p1._value

	settleAllHandlers = (self) ->
		offset = 0
		len = self._hCount

		while offset < len
			settleHandler self, offset

			offset += $groupNum

		return

	###*
	 * Resolve or reject a promise.
	 * @param  {Yaku} self
	 * @param  {Integer} state
	 * @param  {Any} value
	 * @return {Yaku} It will simply return the `self`.
	###
	settlePromise = (self, state, value) ->
		self._state = state
		self._value = value

		return

	###*
	 * Resolve or reject primise with value x. The x can also be a thenable.
	 * @private
	 * @param {Yaku} p
	 * @param {Any | Thenable} x A normal value or a thenable.
	###
	settleValue = (p, x) ->
		if x instanceof Yaku
			addHandler x, p
			return

		type = typeof x
		if x != null and (type == $function or type == $object)
			xthen = genTryCatcher(getThen) x
			if xthen == $tryErr
				settlePromise p, $rejected, xthen.e
				return

			if typeof xthen == $function
				settleXthen p, x, xthen
			else
				settlePromise p, $resolved, x
		else
			settlePromise p, $resolved, x

		return

	###*
	 * Resolve then with its promise.
	 * @private
	 * @param  {Yaku} p
	 * @param  {Thenable} x
	 * @param  {Function} xthen
	###
	settleXthen = (p, x, xthen) ->
		err = genTryCatcher(xthen).call x, (y) ->
			return if not x
			x = null
			settleValue p, y
		, (r) ->
			return if not x
			x = null

			settlePromise p, $rejected, r

		if err == $tryErr and x
			settlePromise p, $rejected, err.e
			x = null

		return

	###*
	 * Try to get a promise's then method.
	 * @private
	 * @param  {Thenable} x
	 * @return {Function}
	###
	getThen = (x) -> x.then

	# ******************************* Utils ********************************

	$tryCatchFn = null
	$tryErr = { e: null }
	$noop = {}
	$function = 'function'
	$object = 'object'

	###*
	 * Release the specified key of an object.
	 * @param  {Object} obj
	 * @param  {String | Number} key
	###
	release = (obj, key) ->
		obj[key] = undefined
		return

	###*
	 * Wrap a function into a try-catch.
	 * @return {Any | $tryErr}
	###
	tryCatcher = ->
		try
			$tryCatchFn.apply @, arguments
		catch e
			$tryErr.e = e
			$tryErr

	###*
	 * Generate a try-catch wrapped function.
	 * @param  {Function} fn
	 * @return {Function}
	###
	genTryCatcher = (fn) ->
		$tryCatchFn = fn
		tryCatcher

	###*
	 * Generate a scheduler.
	 * @private
	 * @param  {Integer}  initQueueSize
	 * @param  {Function} fn `(Yaku, Value) ->` The schedule handler.
	 * @return {Function} `(Yaku, Value) ->` The scheduler.
	###
	genScheduler = (initQueueSize, fn) ->
		###*
		 * All async promise will be scheduled in
		 * here, so that they can be execute on the next tick.
		 * @private
		###
		fnQueue = Array initQueueSize
		fnQueueLen = 0

		###*
		 * Run all queued functions.
		 * @private
		###
		flush = ->
			i = 0
			while i < fnQueueLen
				pIndex = i++
				vIndex = i++

				p = fnQueue[pIndex]
				v = fnQueue[vIndex]

				release fnQueue, pIndex
				release fnQueue, vIndex

				fn p, v

			fnQueueLen = 0
			fnQueue.length = initQueueSize

			return

		###*
		 * Schedule a flush task on the next tick.
		 * @private
		 * @param {Function} fn The flush task.
		###
		scheduleFlush =
			if typeof process == $object and process.nextTick
				->
					process.nextTick flush
					return

			else if typeof setImmediate == $function
				->
					setImmediate flush
					return

			else if typeof MutationObserver == $function
				content = 1
				node = document.createTextNode ''
				observer = new MutationObserver flush
				observer.observe node, characterData: true
				->
					node.data = (content = -content)
					return

			else if typeof document == $object and document.createEvent
				addEventListener '_yakuTick', flush
				->
					evt = document.createEvent 'CustomEvent'
					evt.initCustomEvent '_yakuTick', false, false
					dispatchEvent evt
					return

			else
				->
					setTimeout flush
					return

		(p, v) ->
			fnQueue[fnQueueLen++] = p
			fnQueue[fnQueueLen++] = v

			scheduleFlush() if fnQueueLen == 2

			return

	###*
	 * It will produce a settlePromise function to user.
	 * Such as the resolve and reject in this `new Yaku (resolve, reject) ->`.
	 * @private
	 * @param  {Yaku} self
	 * @param  {Integer} state The value is one of `$pending`, `$resolved` or `$rejected`.
	 * @return {Function} `(value) -> undefined` A resolve or reject function.
	###
	genSettler = (self, state) -> (value) ->
		return if self._state != $pending

		settlePromise self, state, value

		return

	# CMD & AMD Support
	if typeof module == $object and typeof module.exports == $object
		module.exports = Yaku
	else
		if typeof define == $function and define.amd
			define -> Yaku
		else
			window.Yaku = Yaku if typeof window == $object
