

# InterText Lexer `Interlex`


<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [InterText Lexer `Interlex`](#intertext-lexer-interlex)
  - [Notes](#notes)
  - [Adding Lexemes](#adding-lexemes)
  - [Example](#example)
  - [Topological Sorting](#topological-sorting)
  - [Reserved and Catchall Lexemes](#reserved-and-catchall-lexemes)
  - [To Do](#to-do)
  - [Is Done](#is-done)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->


# InterText Lexer `Interlex`


<!-- A collection of *lexemes* defines a *syntax* -->

## Notes

* An 'empty lexer' (i.e. a lexer without any lexemes) will match the empty string and nothing else;
  depending on the lexer's configuration, the former may contain `$start` and / or `$end` tokens, and the
  latter, in addition, may either contain a single `$error` token or else throw an error, as the case may
  be.

## Adding Lexemes

* ATM adding lexemes one by one is supported by calling `lexer.add_lexeme()`
* in the future, defining entire grammars in one go should become possible
* `lexer.add_lexeme()` expects a `cfg` ('configuration') object with the following keys:
  * `cfg.mode`: a valid JS identifier to identify the lexeing mode;
    * if no base mode was passed on instantiation of the lexer, the mode named in the first call
      to `lexer.add_lexeme()` will become the base mode
    * lexing will start from the base mode, which thereby becomes the initial mode (but note that the base
      mode may be re-assumed later without it becoming the initial mode)
  * `cfg.tid`: a valid JS identifier to identify the token / lexeme ID;
  * `cfg.pattern`: a string or a regular expression to describe a constant or variable pattern. Strings will
    be converted to regexes, using proper escaping for all characters that are special in regexes (like `*`,
    `(` and so on);
  * `cfg.jump`: an optional string or function that describes whether to change the lexing mode and / or
    which token should result
    * if `cfg.jump` is a valid JS identifier, then it should be the name of the lexing mode that should be entered
      right after the present token
    * if `cfg.jump` is the caret `^`, this means 'jump back', i.e. resume the previous mode. This causes a
      runtime error in case a jump back from the initial mode is attempted
  * names of modes and lexemes will be used to construct regex group names; therefore, they must all be
    [valid JS identifiers](https://mathiasbynens.be/notes/javascript-identifiers-es6)

## Example

Here is a minimal lexer that understands a tiny fraction of the MarkDown grammar, namely, single stars `*`
for emphasis and single backticks `` ` `` for code spans. The single star will be passed through
as-is inside code spans:

```coffee
{ Interlex
  compose  }        = require '../../../apps/intertext-lexer'
first               = Symbol 'first'
last                = Symbol 'last'
#.........................................................................................................
new_toy_md_lexer = ( mode = 'plain' ) ->
  lexer   = new Interlex { dotall: false, }
  #.........................................................................................................
  lexer.add_lexeme { mode: 'plain',   tid: 'escchr',    jump: null,       pattern:  /\\(?<chr>.)/u,     }
  lexer.add_lexeme { mode: 'plain',   tid: 'star1',     jump: null,       pattern:  /(?<!\*)\*(?!\*)/u, }
  lexer.add_lexeme { mode: 'plain',   tid: 'codespan',  jump: 'literal',  pattern:  /(?<!`)`(?!`)/u,    }
  lexer.add_lexeme { mode: 'plain',   tid: 'other',     jump: null,       pattern:  /[^*`\\]+/u,        }
  lexer.add_lexeme { mode: 'literal', tid: 'codespan',  jump: '^',        pattern:  /(?<!`)`(?!`)/u,    }
  lexer.add_lexeme { mode: 'literal', tid: 'text',      jump: null,       pattern:  /(?:\\`|[^`])+/u,   }
```

## Topological Sorting

Interlex optionally uses topological sorting (provided by
[`ltsort`](https://github.com/loveencounterflow/ltsort), q.v.) of lexemes. This is triggered by adding a
`before` or `after` attribute when calling `leyer.add_lexeme()`. Either attribute may be a TID (which
identifies a lexeme in the same mode) or a list (array) of TIDs. Both values may also be a star `*` meaning
'before' or 'after everything else'. These dependency indicators don't have to be exhaustive; where left
unspecified, the relative ordering of addition of the lexemes is kept.

Observe that ordering is only defined for lexemes *within the same lexer mode*; there's no notion of
relative ordering between lexer modes or lexemes across modes.

## Reserved and Catchall Lexemes

Each lexeme can announce so-called 'reserved' characters or words; these are for now restricted to strings and
lists of strings, but could support regexes in the future as well. The idea is to collect those characters
and character sequences that are 'triggers' for a given lexeme and, when the mode has been defined, to
automatically construct two lexemes that will capture

* all the remaining sequences of non-reserved characters; this is called a *catchall* lexeme (whose TID is
  incidentally set to `$catchall`). The catchall lexeme's function lies in explicitly capturing any part of
  the input that has not been covered by any other lexemer higher up in the chain of patterns, thereby
  avoiding a more unhelpful `$error` token that would just say 'no match at position so-and-so' and
  terminate lexing.

* all the remaining *reserved* characters (TID: `$reserved`); these could conceivably be used to produce a
  list of fishy parts in the source, and / or to highlight such places in the output, or, if one feels so
  inclined, terminate parsing with an error message. For example, when one wants to translate MarkDown-like
  markup syntax to HTML, one could decide that double stars start and end bold type
  (`<strong>...</strong>`), or, when a single asterisk is used at the start of a line, indicate unordered
  list items (`<ul>...<li>...</ul>`), and are considered illegal in any other position except inside code
  stretches and when escaped with a backslash. Such a mechanism can help to uncover problems with the source
  text instead of just glancing over dubious markup and 'just do something', possibly leading to subtle
  errors.

Whether the catchall and the reserved lexemes should match single occurrences or contiguous stretches of
occurrences of reserved items can be set for all modes with the lexer instantiation settings
`catchall_concat` and `reserved_concat`. In the below lexer these have been left to their defaults (no
concatenation called for), but in the last tabular output below the result for a string of 'foreign' and
'reserved' characters with `{ catchall_concat: true, reserved_concat: true, }` is shown.



```coffee
{ Interlex, } = require '../../../apps/intertext-lexer'
### NOTE these are the default settings, shown here for clarity ###
lexer = new Interlex { catchall_concat: false, reserved_concat: false, }
#.........................................................................................................
mode    = 'plain'
lexer.add_lexeme { mode, tid: 'escchr',           pattern:  /\\(?<chr>.)/u, reserved: '\\', }
lexer.add_lexeme { mode, tid: 'star2',            pattern: ( /(?<!\*)\*\*(?!\*)/u   ), reserved: '*', }
lexer.add_lexeme { mode, tid: 'heading',          pattern: ( /^(?<hashes>#+)\s+/u ), reserved: '#', }
lexer.add_lexeme { mode, tid: 'word',             pattern: ( /\p{Letter}+/u ), }
lexer.add_lexeme { mode, tid: 'number_symbol',    pattern: ( /#(?=\p{Number})/u ), }
lexer.add_lexeme { mode, tid: 'number',           pattern: ( /\p{Number}+/u ), }
lexer.add_lexeme { mode, tid: 'ws',               pattern: ( /\s+/u ), }
lexer.add_catchall_lexeme { mode, }
lexer.add_reserved_lexeme { mode, }
#.........................................................................................................
H.tabulate "lexer", ( x for _, x of lexer.registry.plain.lexemes )
for probe in [ 'helo', 'helo*x', '*x', "## question #1 and a hash: #", "## question #1 and a hash: \\#", ]
  debug GUY.trm.reverse GUY.trm.steel probe
  H.tabulate ( rpr probe ), lexer.run probe
```

The lexer's `plain` mode now has a `$catchall` and a `reserved` lexeme:

```
 lexer
┌───────┬───────────────┬─────────────────────────────────────────┬──────┬──────────┬──────────────┐
│mode   │tid            │pattern                                  │jump  │reserved  │type_of_jump  │
├───────┼───────────────┼─────────────────────────────────────────┼──────┼──────────┼──────────────┤
│plain  │escchr         │/(?<𝔛escchr>\\(?<escchr𝔛chr>.))/u        │●     │\         │nojump        │
│plain  │star2          │/(?<𝔛star2>(?<!\*)\*\*(?!\*))/u          │●     │*         │nojump        │
│plain  │heading        │/(?<𝔛heading>^(?<heading𝔛hashes>#+)\s+)/u│●     │#         │nojump        │
│plain  │word           │/(?<𝔛word>\p{Letter}+)/u                 │●     │●         │nojump        │
│plain  │number_symbol  │/(?<𝔛number_symbol>#(?=\p{Number}))/u    │●     │●         │nojump        │
│plain  │number         │/(?<𝔛number>\p{Number}+)/u               │●     │●         │nojump        │
│plain  │ws             │/(?<𝔛ws>\s+)/u                           │●     │●         │nojump        │
│plain  │$catchall      │/(?<𝔛$catchall>(?!\\|\*|#)[^])/          │●     │●         │nojump        │
│plain  │$reserved      │/(?<𝔛$reserved>\\|\*|#)/                 │●     │●         │nojump        │
└───────┴───────────────┴─────────────────────────────────────────┴──────┴──────────┴──────────────┘
```

Results:

```
 'helo'
┌───────┬──────┬────────────┬──────┬───────┬───────┬──────┬────┬────────┐
│mode   │tid   │mk          │jump  │value  │start  │stop  │x   │$key    │
├───────┼──────┼────────────┼──────┼───────┼───────┼──────┼────┼────────┤
│plain  │word  │plain:word  │●     │helo   │0      │4     │●   │^plain  │
└───────┴──────┴────────────┴──────┴───────┴───────┴──────┴────┴────────┘
```

```
 'helo*x'
┌───────┬───────────┬─────────────────┬──────┬───────┬───────┬──────┬────┬────────┐
│mode   │tid        │mk               │jump  │value  │start  │stop  │x   │$key    │
├───────┼───────────┼─────────────────┼──────┼───────┼───────┼──────┼────┼────────┤
│plain  │word       │plain:word       │●     │helo   │0      │4     │●   │^plain  │
│plain  │$reserved  │plain:$reserved  │●     │*      │4      │5     │●   │^plain  │
│plain  │word       │plain:word       │●     │x      │5      │6     │●   │^plain  │
└───────┴───────────┴─────────────────┴──────┴───────┴───────┴──────┴────┴────────┘
```

```
 '*x'
┌───────┬───────────┬─────────────────┬──────┬───────┬───────┬──────┬────┬────────┐
│mode   │tid        │mk               │jump  │value  │start  │stop  │x   │$key    │
├───────┼───────────┼─────────────────┼──────┼───────┼───────┼──────┼────┼────────┤
│plain  │$reserved  │plain:$reserved  │●     │*      │0      │1     │●   │^plain  │
│plain  │word       │plain:word       │●     │x      │1      │2     │●   │^plain  │
└───────┴───────────┴─────────────────┴──────┴───────┴───────┴──────┴────┴────────┘
```

```
 '## question #1 and a hash: #'
┌───────┬───────────────┬─────────────────────┬──────┬──────────┬───────┬──────┬────────────────┬────────┐
│mode   │tid            │mk                   │jump  │value     │start  │stop  │x               │$key    │
├───────┼───────────────┼─────────────────────┼──────┼──────────┼───────┼──────┼────────────────┼────────┤
│plain  │heading        │plain:heading        │●     │##        │0      │3     │{ hashes: '##' }│^plain  │
│plain  │word           │plain:word           │●     │question  │3      │11    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │11     │12    │●               │^plain  │
│plain  │number_symbol  │plain:number_symbol  │●     │#         │12     │13    │●               │^plain  │
│plain  │number         │plain:number         │●     │1         │13     │14    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │14     │15    │●               │^plain  │
│plain  │word           │plain:word           │●     │and       │15     │18    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │18     │19    │●               │^plain  │
│plain  │word           │plain:word           │●     │a         │19     │20    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │20     │21    │●               │^plain  │
│plain  │word           │plain:word           │●     │hash      │21     │25    │●               │^plain  │
│plain  │$catchall      │plain:$catchall      │●     │:         │25     │27    │●               │^plain  │
│plain  │$reserved      │plain:$reserved      │●     │#         │27     │28    │●               │^plain  │
└───────┴───────────────┴─────────────────────┴──────┴──────────┴───────┴──────┴────────────────┴────────┘
```

```
 '## question #1 and a hash: \\#'
┌───────┬───────────────┬─────────────────────┬──────┬──────────┬───────┬──────┬────────────────┬────────┐
│mode   │tid            │mk                   │jump  │value     │start  │stop  │x               │$key    │
├───────┼───────────────┼─────────────────────┼──────┼──────────┼───────┼──────┼────────────────┼────────┤
│plain  │heading        │plain:heading        │●     │##        │0      │3     │{ hashes: '##' }│^plain  │
│plain  │word           │plain:word           │●     │question  │3      │11    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │11     │12    │●               │^plain  │
│plain  │number_symbol  │plain:number_symbol  │●     │#         │12     │13    │●               │^plain  │
│plain  │number         │plain:number         │●     │1         │13     │14    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │14     │15    │●               │^plain  │
│plain  │word           │plain:word           │●     │and       │15     │18    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │18     │19    │●               │^plain  │
│plain  │word           │plain:word           │●     │a         │19     │20    │●               │^plain  │
│plain  │ws             │plain:ws             │●     │          │20     │21    │●               │^plain  │
│plain  │word           │plain:word           │●     │hash      │21     │25    │●               │^plain  │
│plain  │$catchall      │plain:$catchall      │●     │:         │25     │27    │●               │^plain  │
│plain  │escchr         │plain:escchr         │●     │\#        │27     │29    │{ chr: '#' }    │^plain  │
└───────┴───────────────┴─────────────────────┴──────┴──────────┴───────┴──────┴────────────────┴────────┘
```

Result with `lexer = new Interlex { catchall_concat: false, reserved_concat: false, }`:

```
 ':.;*#'
┌───────┬───────────┬─────────────────┬──────┬───────┬───────┬──────┬────┬────────┐
│mode   │tid        │mk               │jump  │value  │start  │stop  │x   │$key    │
├───────┼───────────┼─────────────────┼──────┼───────┼───────┼──────┼────┼────────┤
│plain  │$catchall  │plain:$catchall  │●     │:      │0      │1     │●   │^plain  │
│plain  │$catchall  │plain:$catchall  │●     │.      │1      │2     │●   │^plain  │
│plain  │$catchall  │plain:$catchall  │●     │;      │2      │3     │●   │^plain  │
│plain  │$reserved  │plain:$reserved  │●     │*      │3      │4     │●   │^plain  │
│plain  │$reserved  │plain:$reserved  │●     │#      │4      │5     │●   │^plain  │
└───────┴───────────┴─────────────────┴──────┴───────┴───────┴──────┴────┴────────┘
```

Result with `lexer = new Interlex { catchall_concat: true, reserved_concat: true, }`:

```
 ':.;*#'
┌───────┬───────────┬─────────────────┬──────┬───────┬───────┬──────┬────┬────────┐
│mode   │tid        │mk               │jump  │value  │start  │stop  │x   │$key    │
├───────┼───────────┼─────────────────┼──────┼───────┼───────┼──────┼────┼────────┤
│plain  │$catchall  │plain:$catchall  │●     │:.;    │0      │3     │●   │^plain  │
│plain  │$reserved  │plain:$reserved  │●     │*#     │3      │5     │●   │^plain  │
└───────┴───────────┴─────────────────┴──────┴───────┴───────┴──────┴────┴────────┘
```

## To Do

* **[–]** documentation
* **[–]** allow to configure `start`, `stop`, `error` tokens, implicit `finalize()`
* **[–]** introduce aliases for names of `compose` that don't use snake case &c
* **[–]** implement `line`, `col` coordinates for tokens
* **[–]** group renaming has a fault in that it will wrongly accept things looking like a named group inside
  a squra-bracket character class, as in `/[?<abc>)]`
* **[–]** we cannot mix regexes with and without `s` / `dotall` flag; configure that per mode, per instance?
* **[–]** allow to add lexemes w/out explicit mode, will provide default / add to base mode
* **[–]** use [`datom`s](https://github.com/loveencounterflow/datom)
* **[–]** provide collection of standard lexers for recurring tasks, including an abstracted version of
  MarkDown star lexer
* **[–]** disallow lexemes to be accidentally overwritten
* **[–]** clarify whether to use 'lexeme ID' or 'token ID'; whould really be the former because a lexeme is
  the description ('class' or 'type' if you will) of its instances (the tokens); tokens with the same `tid`
  may repeat while there can only be at most one lexeme with a given `tid` in a given namespace / mode
* **[–]** implement readable representation / RPR for lexers, maybe as table
* **[–]** safeguard against undefined lexemes mentioned by `before`, `after`
* **[–]** distinguish between
  * proto-lexemes (which are lexeme definitions may be incomplete and have not yet been compiled; they are
    'dormant' and stateless),
  * (proper) lexemes (which are lexemes in the registry lexer that is ready to be used; these may be
    stateful), and
  * tokens (the results of certain lexemes having matched at some point in the source text)
* **[–]** allow symbolic mode, jump values as in `'$codespan_mode'` that refer to values in `@cfg`?
* **[–]** allow to set prefixes for input (as class members) and output (as instance members, object
  properties, or list elements)
* **[–]** implement `add_lexemes()` for adding single and multiple lexemes
* **[–]** make use of mode names in `lx_*` properties mandatory to avoid name conflicts

* **[–]** offer text normalization that includes removing trailing whitespace, different line endings
  ```coffee
  echo '–––'; echo "a1 xyz123\nb1"
  echo '–––'; echo "a2 xyz123\n\rb2"
  echo '–––'; echo "a3 xyz123\r\nb3"
  echo '–––'; echo "a4 xyz123\n\nb4"
  echo '–––'; echo "a5 xyz123\n\r\n\rb5"
  echo '–––'; echo "a6 xyz123\n\n\r\rb6"
  echo '–––'; echo "a7 xyz123\r\n\r\nb7"
  echo '–––'; echo "a8 xyz123\r\n\n\rb8"
  /(\n\r|\r\n|\n)/ -> '\n'
  /\r/ -> ''
  ```

  * pay attention to the excellent SO answer https://stackoverflow.com/a/3469155/7568091 who suggests using
    `/[^\S\r\n]/` with double negative (`[^]` plus `\S`) to match linear whitespace only
* **[–]** export `GUY.*.walk_lines()` to promote easy use of line-wise lexing


## Is Done

* **[+]** demo in
  [`hengist/dev/snippets/src/demo-compose-regexp.coffee`](https://github.com/loveencounterflow/hengist/blob/master/dev/snippets/src/demo-compose-regexp.coffee)
  and
  [`hengist/blob/master/dev/intertext-lexer/src/first-demo.coffee`](https://github.com/loveencounterflow/hengist/blob/master/dev/intertext-lexer/src/first-demo.coffee)
* **[+]** prefix named groups for parameters with rule name (token key) to enable re-use of parameter names
* **[+]** allow multiple `gosub_*`, `return` tokens in a single lexer mode; use API rather than naming
  convention for these
* **[+]** implement `cfg`-based API for `add_lexeme()` that provides `jump` argument to replace
  `gosub_`/`return` naming convention
* **[+]** implement `step()`
* **[+]** rename `autoreset`, `reset()` -> `autostart`, `start()`
* **[+]** make calls to `finalize()` implicit
* **[+]** with `cfg.autostart`, `feed()` and `reset()` behave identically
* **[+]** implement `feed()` to add new source
* **[+]** implement functions for `jump`
* **[+]** implement topological sorting of lexemes
* **[+]** allow lexemes to announce 'reserved' / 'forbidden' / 'active' characters (such as `<` that signals
  start of an HTML tag) that can later be used to formulate a fallback pattern to capture otherwise
  unmatched text portions
  * **[+]** at any point, allow to construct a pattern that *only* matches reserved characters and a pattern
    that matches anything *except* reserved characters

