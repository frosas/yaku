###

As a result create funtions at runtime is very expensive.

foo: 269ms
bar: 7ms

###

utils = require './utils'

closure = ->
	countDown = 10 ** 5

	list = []
	len = 0

	async = (fn) ->
		list[len++] = fn

	process.on 'exit', ->
		console.timeEnd()

	foo = ->
		a = 1
		b = 2

		async ->
			a + b
			return

		return

	process.nextTick ->
		for fn in list
			fn()

	console.time()
	i = countDown
	while i--
		foo()

nonClosure = ->
	countDown = 10 ** 5

	list = []
	len = 0

	async = (fn, a, b) ->
		list[len++] = fn
		list[len++] = a
		list[len++] = b

	process.on 'exit', ->
		console.timeEnd()

	bar = (a, b) ->
		a + b
		return

	foo = ->
		a = 1
		b = 2

		async bar, a, b

		return

	process.nextTick ->
		i = 0
		while i < len
			list[i++] list[i++], list[i++]

	console.time()
	c = countDown
	while c--
		foo()

nonClosure()