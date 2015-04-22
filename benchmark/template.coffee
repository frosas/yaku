kit = require 'nokit'
cs = kit.require 'colors/safe'

###*
 * The test will run 10 ^ 5 promises.
 * Each promise will resolve after 1ms.
 * When all tasks are done, print out how much time it takes.
###

module.exports = (name, Promise) ->

	countDown = 10 ** 5

	checkEnd = ->
		return if --countDown
		logResult()

	logResult = ->
		resolutionTime = Date.now() - startResolution

		mem = process.memoryUsage()
		memFormat = []
		for k, v of mem
			memFormat.push "#{k} - #{Math.floor(v / 1024 / 1024)}mb"

		console.log """
		#{cs.cyan kit._.padRight(name, 15)}
		       total: #{cs.green initTime + resolutionTime}ms
		        init: #{initTime}ms
		  resolution: #{resolutionTime}ms
		      memory: #{memFormat.join(' | ')}
		"""

	resolver0 = (resolve) -> resolve()

	resolver1 = (resolve) ->
		setTimeout ->
			resolve()
		, 1

	asyncTask = ->
		new Promise(resolver1).then checkEnd

	i = countDown

	initStart = Date.now()

	while i--
		asyncTask()

	startResolution = Date.now()
	initTime = startResolution - initStart

