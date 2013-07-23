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
    @coffee = {}
    @uglify = {}
    @template = {}
    @concat = {}

    console.log """
      iced: #{grunt.option 'iced'}
      trace: #{grunt.option 'trace'}
    """

    # generate (iced-)coffee-script runtime
    runtime_use_iced = !!grunt.option('iced')
    @coffee.runtime =
      options:
        bare: true
        runtime: if runtime_use_iced then 'window' else 'none'
        runforce: runtime_use_iced
      files: [
        {src: 'src/runtime.iced', dest: 'build/runtime.js'}
      ]
    @uglify.runtime =
      options:
        mangle: false
        compress: false
        preserveComments: false
      files: [
        {src: 'build/runtime.js', dest: 'build/runtime.min.js'}
      ]
    grunt.registerTask 'pack-runtime', ->
      s = grunt.file.read 'build/runtime.min.js', encoding: 'utf-8'
      s = s.replace /\s*\${3,}[\s\S]*/, ''
      grunt.file.write 'build/runtime.packed.iced', """
        COFFEE_RUNTIME = '''
        #{s}
        '''
      """, encoding: 'utf-8'
    grunt.registerTask 'runtime', [
      'coffee:runtime'
      'uglify:runtime'
      'pack-runtime'
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
        {src: ['build/kisume.iced', 'build/runtime.packed.iced'], dest: 'dist/kisume.js'}
      ]
    @uglify.main =
      options:
        mangle: false
        compress: true
        preserveComments: 'some'
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
