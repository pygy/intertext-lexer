
'use strict'


############################################################################################################
GUY                       = require 'guy'
{ alert
  debug
  help
  info
  plain
  praise
  urge
  warn
  whisper }               = GUY.trm.get_loggers 'INTERTEXT-LEXER/SYNTAX'
{ rpr
  inspect
  echo
  log     }               = GUY.trm
{ get_base_types }        = require './types'
E                         = require './errors'


#===========================================================================================================
#
#===========================================================================================================
class Syntax

  ###
  * lexemes to be declared as *static* members (i.e. as class attributes) will be compiled
  * lexeme factories that need additional parameters should use the prefix `new_` and be put on the
    instance
  * lexeme factories that are defined on the class will be called with the implicit `this`/`@` being the
    *instance*, not the class

  * specials:
    `@mode` indicates the (name of the) (base) mode; this can be overridden at instantiation time
    `@mode_*` indicate the (names of the) other modes; these can be overridden at instantiation time

  * use prefix `@lx_*` for string, regex, object, or a list thereof; alternatively a function returning one
    of the aforementioned
  * use prefix `new_*` for lexeme-factories that need additional parameters

  * TID (the lexeme's name) will default to the part after the prefix

  ```coffee
  class ClassWithStaticMethod
    @staticProperty: 'someValue'
    @staticMethod: () ->
      return 'static method has been called.'
  ```

  ```js
  class ClassWithStaticMethod {
    static staticProperty = 'someValue';
    static staticMethod() {
      return 'static method has been called.'; } }
  ```

  ###

  #---------------------------------------------------------------------------------------------------------
  constructor: ( cfg ) ->
    GUY.props.hide @, 'types', get_base_types()
    ### TAINT must separate `cfg` items for the instance from defaults for the lexeme ###
    @cfg                  = { mode: 'std', cfg..., }
    @_lexeme_default      = { @types.registry.ilx_add_lexeme_cfg.default..., }
    lexeme_keys           = new Set Object.keys @_lexeme_default
    @_lexeme_default[ k ] = v for k, v of @cfg when lexeme_keys.has k
    @_compile_lexemes()
    return undefined

  #---------------------------------------------------------------------------------------------------------
  _compile_list_of_lexemes: ( tid, list_of_lexemes ) ->
    return ( ( @_compile_lexeme ( "#{tid}_#{idx + 1}" ), lexeme ) for lexeme, idx in list_of_lexemes )

  #---------------------------------------------------------------------------------------------------------
  _compile_lexeme: ( tid, lexeme ) ->
    lexeme  = { tid, pattern: lexeme, } if @types.isa.ilx_pattern lexeme
    lexeme  = { @_lexeme_default..., lexeme..., } if @types.isa.object lexeme
    @types.validate.ilx_add_lexeme_cfg lexeme
    return lexeme

  #---------------------------------------------------------------------------------------------------------
  _compile_lexemes: ->
    for xtid in Object.getOwnPropertyNames @constructor
      continue unless ( match = xtid.match /^(?<get>get_|)(?<number>lxs?_)(?<tid>.+)$/ )?
      { get, number, tid, } = match.groups
      is_function           = get isnt ''
      number                = if number is 'lx_' then 'singular' else 'plural'
      lexeme                = @constructor[ xtid ]
      lx_type               = @types.type_of lexeme
      urge '^32-4^', { xtid, tid, number, lexeme, }
      try
        if is_function
          null
        else
          if number is 'singular'
            if lx_type is 'list'
              throw new Error "^238947^ must use prefix 'lxs_' for list of lexemes; got #{rpr xtid}"
            lexeme = @_compile_lexeme tid, lexeme
          else
            lexeme = @_compile_list_of_lexemes tid, lexeme
      catch error
        throw error unless error.constructor.name is 'Intertype_validation_error'
        # error.message
        throw error
      debug '^32-5^', lexeme
      @[ xtid ] = lexeme
      # #.....................................................................................................
      # switch type = @types.type_of lexeme
      #   when 'object' then @[ tid ] = { @cfg..., lexeme..., }
      #   when 'list'   then @[ tid ] = ( { @cfg..., lx..., } for lx in lexeme )
      #   #...................................................................................................
      #   when 'function'
      #     lexeme = lexeme.call @
      #     switch subtype = type_of lexeme
      #       when 'object' then  @[ tid ] = lexeme ### NOTE lexemes returned by functions should be complete ###
      #       when 'list'   then  @[ tid ] = lexeme ### NOTE lexemes returned by functions should be complete ###
      #       else throw new Error "^849687388^ expected an object or a list of objects, found a #{type}"
      #   #...................................................................................................
      #   else throw new Error "^849687349^ expected an object or a function, found a #{type}"
    return null


#===========================================================================================================
module.exports = { Syntax, }




