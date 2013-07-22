module.exports = (grunt) ->
  'use strict'


  ############
  # plugins

  [
    'grunt-iced-coffee'
    'grunt-contrib-concat'
    'grunt-contrib-clean'
    'grunt-contrib-uglify'
  ].map (x) -> grunt.loadNpmTasks(x)

  # template
  grunt.registerMultiTask 'template', ->
    for x in @files
      cont = ''
      for src in x.src
        cont += grunt.template.process grunt.file.read(src, encoding: 'utf-8')
      cont = cont.replace(/\r\n/g, '\n')
      grunt.file.write(x.dest, cont, encoding: 'utf-8')


  ############
  # config

  grunt.initConfig new ->
    @pkg = grunt.file.readJSON('package.json')

    # default
    @clean =
      build: ['build/*']
      dist: ['dist/*']
    @coffee =
      options:
        bare: true
    @uglify =
      options:
        preserveComments: 'some'
    @template = {}
    @concat = {}

    # generate (iced-)coffee-script runtime
    runtime_use_iced = !!grunt.option('iced')
    @coffee.runtime =
      options:
        runtime: if runtime_use_iced then 'window' else 'none'
        runforce: runtime_use_iced
      files: [
        {src: 'src/runtime.iced', dest: 'build/runtime.generated.js'}
      ]
    grunt.registerTask 'runtime-strip', ->
      s = grunt.file.read 'build/runtime.generated.js', encoding: 'utf-8'
      s = s.replace ///
        ^\s*
        \(function\(\)\s*\{
          [\s\S]+
        \}\);
        \s*
      ///m, ''
      grunt.file.write 'build/runtime.iced', """
        COFFEE_RUNTIME = '''
        #{s}
        '''
      """, encoding: 'utf-8'
    grunt.registerTask 'runtime', [
      'coffee:runtime'
      'runtime-strip'
    ]

    # main code
    @TRACE = !!grunt.option('trace')
    @template.main =
      files: [
        {src: 'src/kisume.tmpl.iced', dest: 'build/kisume.iced'}
      ]
    @coffee.main =
      options:
        bare: false
        join: true
        runtime: 'window'
      files: [
        {src: ['build/runtime.iced', 'build/kisume.iced'], dest: 'dist/kisume.js'}
      ]
    @uglify.main =
      options:
        mangle: false
        compress: true
      files: [
        {src: 'dist/kisume.js', dest: 'dist/kisume.min.js'}
      ]
    grunt.registerTask 'main', [
      'template:main'
      'coffee:main'
      'uglify:main'
    ]

    this # grunt.initConfig

  grunt.registerTask 'default', [
    'runtime'
    'main'
  ]
