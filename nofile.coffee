kit = require 'nokit'
kit.require 'drives'

module.exports = (task, option) ->

	task 'default build', ['doc', 'code']

	task 'doc', ['code', 'utils'], 'build doc', ->
		size = kit.statSync('lib/yaku.min.js').size / 1024
		kit.warp 'src/*.coffee'
		.load kit.drives.comment2md {
			tpl: 'docs/readme.jst.md'
			doc: {
				size: size.toFixed 1
			}
		}
		.run()

	task 'code', 'build source code', ->
		addLicense = (str) ->
			{ version } = kit.require './package', __dirname
			return """
			/*
			 Yaku v#{version}
			 (c) 2015 Yad Smood. http://ysmood.org
			 License MIT
			*/\n
			""" + str

		kit.warp 'src/yaku.coffee'
		.load kit.drives.auto 'lint'
		.load kit.drives.auto 'compile'
		.load (f) ->
			f.dest.name = 'yaku.min'
			kit.outputFile 'lib/yaku.js', addLicense(f.contents)
		.load kit.drives.auto 'compress'
		.load (f) ->
			f.set addLicense f.contents
		.run 'lib'

	task 'utils', 'build utils', ->
		kit.warp 'src/utils.coffee'
		.load kit.drives.auto 'lint'
		.load kit.drives.auto 'compile'
		.run 'lib'

	option '--debug', 'run with remote debug server'
	option '--port <8219>', 'remote debug server port', 8219
	task 'lab l', 'run and monitor "test/lab.coffee"', (opts) ->
		args = ['test/lab.coffee']

		if opts.debug
			kit.log opts.debug
			args.splice 0, 0, '--nodejs', '--debug-brk=' + opts.port

		kit.monitorApp { bin: 'coffee', args }

	option '--grep <pattern>', 'run test that match the pattern', '.'
	task 'test', 'run promise/A+ tests', (opts) ->
		if opts.grep == '.'
			require './test/basic'

		setTimeout ->
			require('./test/compliance.coffee') {
				grep: opts.grep
			}
		, 1000

	option '--sync', 'sync benchmark'
	task 'benchmark', ['build']
	, 'compare performance between different libraries'
	, (opts) ->
		process.env.NODE_ENV = 'production'
		os = require 'os'

		console.log """
			Node #{process.version}
			OS   #{os.platform()}
			Arch #{os.arch()}
			CPU  #{os.cpus()[0].model}
			#{kit._.repeat('-', 80)}
		"""

		paths = kit.globSync 'benchmark/*.coffee'

		sync = if opts.sync then 'sync' else ''
		kit.async paths.map (path) -> ->
			kit.spawn 'coffee', [path, sync]

	task 'clean', 'Clean temp files', ->
		kit.remove '{.nokit,lib,.coffee,.nobone}'

	option '--browserPort <8227>', 'browser test port', 8227
	task 'browser', 'Unit test on browser', (opts) ->
		http = require 'http'

		server = http.createServer (req, res) ->
			switch req.url
				when '/'
					kit.readFile 'test/browser.html', (html) ->
						all = ''
						kit.warp([
							'src/yaku.coffee'
							'test/basic.coffee'
						])
						.load kit.drives.auto 'compile'
						.load (f) ->
							all += f.contents + '\n\n'
							f.contents = null
						.run().then ->
							res.end """
								<html>
									<body></body>
									<script>#{all}</script>
								</html>"""
				when '/log'
					req.on 'data', (c) ->
						info = c.toString()
						console.log info
					req.on 'end', ->
						res.end()
				else
					res.statusCode = 404
					res.end()

		server.listen opts.browserPort, ->
			kit.log 'Listen ' + opts.browserPort
			kit.xopen 'http://127.0.0.1:' + opts.browserPort