

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
		executor genResolver(@, $resolved), genResolver(@, $rejected)

	###*
	 * Appends fulfillment and rejection handlers to the promise,
	 * and returns a new promise resolving to the return value of the called handler.
	 * @param  {Function} onFulfilled Optional. Called when the Promise is resolved.
	 * @param  {Function} onRejected  Optional. Called when the Promise is rejected.
	 * @return {Yaku} It will return a new Yaku which will resolve or reject after
	 * the current Promise.
	###
	then: (onFulfilled, onRejected) ->
		p = new Yaku $noop

		offset = @_hCount
		@[offset] = onFulfilled if typeof onFulfilled == $function
		@[offset + 1] = onRejected if typeof onRejected == $function
		@[offset + 2] = p
		@_hCount += $groupNum

		if @_state != $pending
			settleHandler @, offset

		p

	###*
	 * The catch() method returns a Promise and deals with rejected cases only.
	 * It behaves the same as calling `Promise.prototype.then(undefined, onRejected)`.
	 * @param  {Function} onRejected A Function called when the Promise is rejected.
	 * This function has one argument, the rejection reason.
	 * @return {Yaku} A Promise that deals with rejected cases only.
	###
	catch: (onRejected) ->
		@then undefined, onRejected

	###*
	 * The Promise. resolve(value) method returns a Promise object that is resolved with the given value.
	 * If the value is a thenable (i.e. has a then method), the returned promise will "follow" that thenable,
	 * adopting its eventual state; otherwise the returned promise will be fulfilled with the value.
	 * @param  {Any} value Argument to be resolved by this Promise.
	 * Can also be a Promise or a thenable to resolve.
	 * @return {Yaku}
	###
	@resolve: (value) ->
		settlePromise new Yaku($noop), $resolved, value

	###*
	 * The Promise.reject(reason) method returns a Promise object that is rejected with the given reason.
	 * @param  {Any} reason Reason why this Promise rejected.
	 * @return {Yaku}
	###
	@reject: (reason) ->
		settlePromise new Yaku($noop), $rejected, reason

	###*
	 * The Promise.race(iterable) method returns a promise that resolves or rejects
	 * as soon as one of the promises in the iterable resolves or rejects,
	 * with the value or reason from that promise.
	 * @param  {iterable} iterable An iterable object, such as an Array.
	 * @return {Yaku} The race function returns a Promise that is settled
	 * the same way as the first passed promise to settle.
	 * It resolves or rejects, whichever happens first.
	###
	@race: (iterable) ->
		new Yaku (resolve, reject) ->
			for x in iterable
				resolveValue x, resolve, reject
			return

	###*
	 * The `Promise.all(iterable)` method returns a promise that resolves when
	 * all of the promises in the iterable argument have resolved.
	 *
	 * The result is passed as an array of values from all the promises.
	 * If something passed in the iterable array is not a promise,
	 * it's converted to one by Promise.resolve. If any of the passed in promises rejects,
	 * the all Promise immediately rejects with the value of the promise that rejected,
	 * discarding all the other promises whether or not they have resolved.
	 * @param  {iterable} iterable An iterable object, such as an Array.
	 * @return {Yaku}
	###
	@all: (iterable) ->
		new Yaku (resolve, reject) ->
			res = []
			countDown = iterable.length

			iter = (i) ->
				resolveValue x, (v) ->
					res[i] = v
					if --countDown == 0
						resolve res
				, reject

				return

			for x, i in iterable
				iter i

			return

# ********************** Private **********************

	###
	 * 'bind' and 'call' is slow, so we use Python
	 * style "self" with curry and closure.
	 * See: http://jsperf.com/call-vs-arguments
	 *
	 * All static variable name will begin with `$`. Such as `$rejected`.
	 * @private
	###

	# ************************ Private Constant Start *************************

	###*
	 * These are some static symbolys.
	 * The state value is designed to be 0, 1, 2. Not by chance.
	 * See the genResolver part's selector.
	 * @private
	###
	$resolved = 0
	$rejected = 1
	$pending = 2

	###*
	 * This is one of the most tricky part.
	 *
	 * For better performance, both memory and speed, the array is like below,
	 * every 5 entities are paired together as a group:
	 * ```
	 *   0            1           2       ...
	 * [ onFulfilled, onRejected, promise ... ]
	 * ```
	 * To save memory the position of 0 and 1 may be replaced with their returned values,
	 * then these values will be passed to 2 and 3.
	 * @private
	###
	$groupNum = 3

	# These are some symbols. They won't be used to store data.
	$circularError = 'circular promise resolution chain'
	$tryCatchFn = null
	$tryErr = { e: null }
	$noop = {}
	$function = 'function'
	$object = 'object'

	# ************************* Private Constant End **************************

	# Default state
	_state: $pending

	###*
	 * The number of current handlers that attach to this Yaku instance.
	 * @private
	###
	_hCount: 0

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
	 * All onFulfilled and onRejected functions will be scheduled in
	 * here, so that they can be execute on the next tick.
	 * @private
	###
	fnQueue = Array 1000
	fnQueueLen = 0

	###*
	 * Run all queued functions.
	 * @private
	###
	flush = ->
		i = 0
		while i < fnQueueLen
			fIndex = i++
			pIndex = i++
			vIndex = i++

			f = fnQueue[fIndex]
			p = fnQueue[pIndex]
			v = fnQueue[vIndex]

			release fnQueue, fIndex
			release fnQueue, pIndex
			release fnQueue, vIndex

			f p, v

		fnQueueLen = 0

		return

	###*
	 * Schedule a function. The function will run on the next tick.
	 * @private
	 * @param  {Function} fn
	 * @param {Yaku} p
	 * @param {Any} v
	###
	scheduleFn = (fn, p, v) ->
		fnQueue[fnQueueLen++] = fn
		fnQueue[fnQueueLen++] = p
		fnQueue[fnQueueLen++] = v

		scheduleFlush() if fnQueueLen == 3

		return

	# Schedule a flush task on the next tick.
	scheduleFlush = do ->
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

	###*
	 * Resolve or reject primise with value x. The x can also be a thenable.
	 * @private
	 * @param {Yaku} p
	 * @param {Any | Thenable} x A normal value or a thenable.
	###
	resolveValue = (p, x) ->
		type = typeof x
		if x != null and (type == $function or type == $object)
			xthen = genTryCatcher(getXthen) x
			if xthen == $tryErr
				settlePromise p, $rejected, xthen.e
				return

			if typeof xthen == $function
				resolveXthen p, x, xthen
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
	resolveXthen = (p, x, xthen) ->
		err = genTryCatcher(xthen).call x, (y) ->
			return if not x
			x = null
			resolveValue p, y
		, (r) ->
			return if not x
			x = null

			# To prevent the resolving circular we have to
			# make this action on the next tick.
			scheduleFn rejectPromise, p, r

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
	getXthen = (x) -> x.then

	###*
	 * Try to get return value of `onFulfilled` or `onRejected`.
	 * @private
	 * @param  {Yaku} self
	 * @param  {Integer} hIndex
	 * @return {Any}
	###
	getX = (self, hIndex) ->
		handler = self[hIndex]
		release self, hIndex
		handler self._value

	###*
	 * Resolve the value returned by onFulfilled or onRejected.
	 * @param  {Yaku} self
	 * @param  {Integer} offset
	###
	resolveX = (self, offset) ->
		pIndex = offset + 2
		p = self[pIndex]
		release self, pIndex

		x = genTryCatcher(getX) self, offset + self._state
		if x == $tryErr
			settlePromise p, $rejected, x.e
			return

		# Prevent circular chain.
		if x == p and x
			rejector = x[offset + 1]
			if rejector
				rejector new TypeError $circularError
			return

		resolveValue p, x

		return

	###*
	 * Decide how handlers works.
	 * @private
	 * @param  {Yaku} self
	 * @param  {Integer} offset The offset of the handler group.
	###
	settleHandler = (self, offset) ->
		# Trick: Reuse the value of state as the handler selector.
		# The "i + state" shows the math nature of promise.
		if self[offset + self._state]
			scheduleFn resolveX, self, offset
		else
			pIndex = offset + 2
			settlePromise self[pIndex], self._state, self._value
			release self, pIndex

		return

	###*
	 * Reject a promise with passed reason.
	 * @param  {Yaku} p
	 * @param  {Any} r
	###
	rejectPromise = (p, r) ->
		settlePromise p, $rejected, r
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

		offset = 0
		len = self._hCount

		while offset < len
			settleHandler self, offset

			offset += $groupNum

		self

	###*
	 * It will produce a settlePromise function to user.
	 * Such as the resolve and reject in this `new Yaku (resolve, reject) ->`.
	 * @private
	 * @param  {Yaku} self
	 * @param  {Integer} state The value is one of `$pending`, `$resolved` or `$rejected`.
	 * @return {Function} `(value) -> undefined` A resolve or reject function.
	###
	genResolver = (self, state) -> (value) ->
		return if self._state != $pending

		settlePromise self, state, value

	# CMD & AMD Support
	if typeof module == $object and typeof module.exports == $object
		module.exports = Yaku
	else
		if typeof define == $function and define.amd
			define -> Yaku
		else
			window.Yaku = Yaku if typeof window == $object
