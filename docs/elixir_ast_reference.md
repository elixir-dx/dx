# Elixir AST Reference

Generated during `MIX_ENV=dev` compilation by `Dx.Dev.ElixirSyntaxReference`.

Each expanded AST below is read from `Module.get_definition/2` inside an `@before_compile` hook, after Elixir has expanded macros and compiler syntax.

## Table of Contents

- [Literals](#literals)
  - [Integer (decimal)](#integer-decimal)
  - [Integer (hex)](#integer-hex)
  - [Integer (octal)](#integer-octal)
  - [Integer (binary)](#integer-binary)
  - [Integer (underscore)](#integer-underscore)
  - [Float](#float)
  - [Float (scientific)](#float-scientific)
  - [Atom](#atom)
  - [Atom (quoted)](#atom-quoted)
  - [Boolean](#boolean)
  - [Nil](#nil)
  - [String](#string)
  - [String (interpolation)](#string-interpolation)
  - [String (escape)](#string-escape)
  - [String (heredoc)](#string-heredoc)
  - [Charlist](#charlist)
  - [Range](#range)
  - [Range (step)](#range-step)

- [Data Structures](#data-structures)
  - [List](#list)
  - [List (cons)](#list-cons)
  - [Tuple](#tuple)
  - [Map](#map)
  - [Map (arrow keys)](#map-arrow-keys)
  - [Map (update)](#map-update)
  - [Keyword list](#keyword-list)
  - [Struct (create)](#struct-create)
  - [Struct (update)](#struct-update)
  - [Binary](#binary)
  - [Bitstring](#bitstring)
  - [Binary (utf8)](#binary-utf8)
  - [Binary (size)](#binary-size)

- [Operators](#operators)
  - [Arithmetic](#arithmetic)
  - [Integer division](#integer-division)
  - [Remainder](#remainder)
  - [Comparison](#comparison)
  - [Strict comparison](#strict-comparison)
  - [Ordering](#ordering)
  - [and](#and)
  - [or](#or)
  - [not](#not)
  - [&&](#operator-and-and)
  - [||](#operator-or-or)
  - [!](#operator-bang)
  - [Boolean (strict)](#boolean-strict)
  - [Boolean (relaxed)](#boolean-relaxed)
  - [String concat](#string-concat)
  - [List concat](#list-concat)
  - [List subtract](#list-subtract)
  - [Match](#match)
  - [Pin](#pin)
  - [Pipe](#pipe)
  - [Capture (named)](#capture-named)
  - [Capture (anonymous)](#capture-anonymous)
  - [Access](#access)
  - [Membership](#membership)
  - [Ternary-like](#ternary-like)

- [Pattern Matching](#pattern-matching)
  - [Variable binding](#variable-binding)
  - [Tuple destructure](#tuple-destructure)
  - [List destructure](#list-destructure)
  - [Map destructure](#map-destructure)
  - [Struct destructure](#struct-destructure)
  - [Pin in pattern](#pin-in-pattern)
  - [Binary pattern](#binary-pattern)
  - [Ignore value](#ignore-value)
  - [Named ignore](#named-ignore)

- [Control Flow](#control-flow)
  - [case](#case)
  - [case (guard)](#case-guard)
  - [cond](#cond)
  - [if](#if)
  - [if (inline)](#if-inline)
  - [unless](#unless)
  - [with](#with)
  - [with (else)](#with-else)

- [Error Handling](#error-handling)
  - [try/rescue](#tryrescue)
  - [try/catch](#trycatch)
  - [try/after](#tryafter)
  - [raise](#raise)
  - [raise (struct)](#raise-struct)
  - [reraise](#reraise)
  - [throw](#throw)

- [Functions](#functions)
  - [Anonymous (fn)](#anonymous-fn)
  - [Anonymous (multi-clause)](#anonymous-multi-clause)
  - [Capture (remote)](#capture-remote)
  - [Capture (local)](#capture-local)
  - [Capture (partial)](#capture-partial)
  - [Function call](#function-call)

- [Comprehensions](#comprehensions)
  - [for (basic)](#for-basic)
  - [for (filter)](#for-filter)
  - [for (multiple)](#for-multiple)
  - [for (into)](#for-into)
  - [for (reduce)](#for-reduce)
  - [for (uniq)](#for-uniq)
  - [for (binary)](#for-binary)

- [Concurrency](#concurrency)
  - [receive](#receive)
  - [receive (after)](#receive-after)
  - [send](#send)
  - [spawn](#spawn)
  - [spawn (MFA)](#spawn-mfa)
  - [self](#self)

- [Metaprogramming](#metaprogramming)
  - [quote](#quote)
  - [quote (unquote)](#quote-unquote)
  - [quote (unquote_splicing)](#quote-unquote_splicing)
  - [__MODULE__](#__module__)
  - [__ENV__](#__env__)
  - [__DIR__](#__dir__)
  - [__CALLER__](#__caller__)
  - [__STACKTRACE__](#__stacktrace__)

- [Sigils](#sigils)
  - [~s (string)](#s-string)
  - [~S (string raw)](#s-string-raw)
  - [~c (charlist)](#c-charlist)
  - [~w (word list)](#w-word-list)
  - [~w (atoms)](#w-atoms)
  - [~r (regex)](#r-regex)
  - [~D (date)](#d-date)
  - [~T (time)](#t-time)
  - [~N (naive datetime)](#n-naive-datetime)
  - [~U (UTC datetime)](#u-utc-datetime)

- [Access and Updates](#access-and-updates)
  - [Bracket access](#bracket-access)
  - [get_in](#get_in)
  - [put_in](#put_in)
  - [update_in](#update_in)
  - [get_and_update_in](#get_and_update_in)
  - [pop_in](#pop_in)
  - [tap](#tap)
  - [then](#then)

- [Module Directives](#module-directives)
  - [import](#import)
  - [alias](#alias)
  - [require](#require)
  - [Module attribute](#module-attribute)
  - [Block (keyword)](#block-keyword)

## Literals

<a id="integer-decimal"></a>

### Integer (decimal)

Base 10 integer

**Code:**
```elixir
42
```

**Expanded AST:**
```elixir
42
```

---

<a id="integer-hex"></a>

### Integer (hex)

Hexadecimal integer

**Code:**
```elixir
0xFF
```

**Expanded AST:**
```elixir
255
```

---

<a id="integer-octal"></a>

### Integer (octal)

Octal integer

**Code:**
```elixir
0o755
```

**Expanded AST:**
```elixir
493
```

---

<a id="integer-binary"></a>

### Integer (binary)

Binary integer

**Code:**
```elixir
0b1010
```

**Expanded AST:**
```elixir
10
```

---

<a id="integer-underscore"></a>

### Integer (underscore)

Integer with separators

**Code:**
```elixir
1_000_000
```

**Expanded AST:**
```elixir
1000000
```

---

<a id="float"></a>

### Float

Floating point number

**Code:**
```elixir
3.14159
```

**Expanded AST:**
```elixir
3.14159
```

---

<a id="float-scientific"></a>

### Float (scientific)

Scientific notation

**Code:**
```elixir
1.0e-10
```

**Expanded AST:**
```elixir
1.0e-10
```

---

<a id="atom"></a>

### Atom

Named constant

**Code:**
```elixir
:hello
```

**Expanded AST:**
```elixir
:hello
```

---

<a id="atom-quoted"></a>

### Atom (quoted)

Atom with special characters

**Code:**
```elixir
:"hello world"
```

**Expanded AST:**
```elixir
:"hello world"
```

---

<a id="boolean"></a>

### Boolean

Boolean atom

**Code:**
```elixir
true
```

**Expanded AST:**
```elixir
true
```

---

<a id="nil"></a>

### Nil

Nil atom

**Code:**
```elixir
nil
```

**Expanded AST:**
```elixir
nil
```

---

<a id="string"></a>

### String

UTF-8 binary string

**Code:**
```elixir
"hello"
```

**Expanded AST:**
```elixir
"hello"
```

---

<a id="string-interpolation"></a>

### String (interpolation)

String interpolation

**Code:**
```elixir
"hello #{name}"
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 234, column: 5],
 [
   {:"::", [inferred_bitstring_spec: true, line: 234, column: 5],
    ["hello ", {:binary, [line: 234, column: 5], nil}]},
   {:"::", [line: 234, column: 12],
    [
      {{:., [line: 234], [String.Chars, :to_string]}, [line: 234],
       [{:name, [version: 0, line: 234, column: 14], nil}]},
      {:binary, [], nil}
    ]}
 ]}
```

---

<a id="string-escape"></a>

### String (escape)

Escape sequence

**Code:**
```elixir
"line1\nline2"
```

**Expanded AST:**
```elixir
"line1\nline2"
```

---

<a id="string-heredoc"></a>

### String (heredoc)

Heredoc string

**Code:**
```elixir
"""
    hello
    world
    """
```

**Expanded AST:**
```elixir
"hello\nworld\n"
```

---

<a id="charlist"></a>

### Charlist

List of codepoints

**Code:**
```elixir
~c"hello"
```

**Expanded AST:**
```elixir
~c"hello"
```

---

<a id="range"></a>

### Range

Inclusive integer range

**Code:**
```elixir
1..10
```

**Expanded AST:**
```elixir
{:%, [line: 256], [Range, {:%{}, [line: 256], [first: 1, last: 10, step: 1]}]}
```

---

<a id="range-step"></a>

### Range (step)

Range with step

**Code:**
```elixir
1..10//2
```

**Expanded AST:**
```elixir
{:%, [line: 260], [Range, {:%{}, [line: 260], [first: 1, last: 10, step: 2]}]}
```

## Data Structures

<a id="list"></a>

### List

Linked list

**Code:**
```elixir
[1, 2, 3]
```

**Expanded AST:**
```elixir
[1, 2, 3]
```

---

<a id="list-cons"></a>

### List (cons)

Head/tail list construction

**Code:**
```elixir
[head | tail]
```

**Expanded AST:**
```elixir
[
  {:|, [line: 270, column: 11],
   [
     {:head, [version: 0, line: 270, column: 6], nil},
     {:tail, [version: 1, line: 270, column: 13], nil}
   ]}
]
```

---

<a id="tuple"></a>

### Tuple

Fixed-size container

**Code:**
```elixir
{:ok, value}
```

**Expanded AST:**
```elixir
{:ok, {:value, [version: 0, line: 276, column: 11], nil}}
```

---

<a id="map"></a>

### Map

Atom-keyed map

**Code:**
```elixir
%{name: "Alice", age: 30}
```

**Expanded AST:**
```elixir
{:%{}, [line: 280, column: 5], [age: 30, name: "Alice"]}
```

---

<a id="map-arrow-keys"></a>

### Map (arrow keys)

Map with non-atom keys

**Code:**
```elixir
%{"key" => value}
```

**Expanded AST:**
```elixir
{:%{}, [line: 286, column: 5],
 [{"key", {:value, [version: 0, line: 286, column: 16], nil}}]}
```

---

<a id="map-update"></a>

### Map (update)

Map update syntax

**Code:**
```elixir
%{map | key: new_value}
```

**Expanded AST:**
```elixir
{:%{}, [line: 292, column: 5],
 [
   {:|, [line: 292, column: 11],
    [
      {:map, [version: 0, line: 292, column: 7], nil},
      [key: {:new_value, [version: 1, line: 292, column: 18], nil}]
    ]}
 ]}
```

---

<a id="keyword-list"></a>

### Keyword list

Ordered atom-keyed list

**Code:**
```elixir
[name: "Alice", age: 30]
```

**Expanded AST:**
```elixir
[name: "Alice", age: 30]
```

---

<a id="struct-create"></a>

### Struct (create)

Struct creation

**Code:**
```elixir
%User{name: "Alice"}
```

**Expanded AST:**
```elixir
{:%, [line: 302, column: 5],
 [
   Dx.Dev.ElixirSyntaxReference.User,
   {:%{}, [line: 302, column: 39], [age: nil, name: "Alice"]}
 ]}
```

---

<a id="struct-update"></a>

### Struct (update)

Struct update syntax

**Code:**
```elixir
%{user | name: "Bob"}
```

**Expanded AST:**
```elixir
{:%{}, [line: 308, column: 5],
 [
   {:|, [line: 308, column: 12],
    [{:user, [version: 0, line: 308, column: 7], nil}, [name: "Bob"]]}
 ]}
```

---

<a id="binary"></a>

### Binary

Byte sequence

**Code:**
```elixir
<<1, 2, 3>>
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 312, column: 5],
 [
   {:"::", [inferred_bitstring_spec: true, line: 312, column: 5],
    [1, {:integer, [line: 312, column: 5], nil}]},
   {:"::", [inferred_bitstring_spec: true, line: 312, column: 5],
    [2, {:integer, [line: 312, column: 5], nil}]},
   {:"::", [inferred_bitstring_spec: true, line: 312, column: 5],
    [3, {:integer, [line: 312, column: 5], nil}]}
 ]}
```

---

<a id="bitstring"></a>

### Bitstring

Bit-level binary segments

**Code:**
```elixir
<<1::4, 2::4>>
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 316, column: 5],
 [
   {:"::", [line: 316, column: 8],
    [1, {:-, [line: 316, column: 8], [{:integer, [], nil}, {:size, [], [4]}]}]},
   {:"::", [line: 316, column: 14],
    [2, {:-, [line: 316, column: 14], [{:integer, [], nil}, {:size, [], [4]}]}]}
 ]}
```

---

<a id="binary-utf8"></a>

### Binary (utf8)

UTF-8 binary segment

**Code:**
```elixir
<<x::utf8>>
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 322, column: 5],
 [
   {:"::", [line: 322, column: 8],
    [{:x, [version: 0, line: 322, column: 7], nil}, {:utf8, [], nil}]}
 ]}
```

---

<a id="binary-size"></a>

### Binary (size)

Sized binary segment

**Code:**
```elixir
<<x::binary-size(4)>>
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 328, column: 5],
 [
   {:"::", [line: 328, column: 8],
    [
      {:x, [version: 0, line: 328, column: 7], nil},
      {:-, [line: 328, column: 8], [{:binary, [], nil}, {:size, [], [4]}]}
    ]}
 ]}
```

## Operators

<a id="arithmetic"></a>

### Arithmetic

Arithmetic precedence

**Code:**
```elixir
a + b * c / d - e
```

**Expanded AST:**
```elixir
{{:., [line: 334, column: 19], [:erlang, :-]}, [line: 334, column: 19],
 [
   {{:., [line: 334, column: 7], [:erlang, :+]}, [line: 334, column: 7],
    [
      {:a, [version: 0, line: 334, column: 5], nil},
      {{:., [line: 334, column: 15], [:erlang, :/]}, [line: 334, column: 15],
       [
         {{:., [line: 334, column: 11], [:erlang, :*]}, [line: 334, column: 11],
          [
            {:b, [version: 1, line: 334, column: 9], nil},
            {:c, [version: 2, line: 334, column: 13], nil}
          ]},
         {:d, [version: 3, line: 334, column: 17], nil}
       ]}
    ]},
   {:e, [version: 4, line: 334, column: 21], nil}
 ]}
```

---

<a id="integer-division"></a>

### Integer division

Integer division function

**Code:**
```elixir
div(10, 3)
```

**Expanded AST:**
```elixir
{{:., [line: 338, column: 5], [:erlang, :div]}, [line: 338, column: 5], [10, 3]}
```

---

<a id="remainder"></a>

### Remainder

Remainder function

**Code:**
```elixir
rem(10, 3)
```

**Expanded AST:**
```elixir
{{:., [line: 342, column: 5], [:erlang, :rem]}, [line: 342, column: 5], [10, 3]}
```

---

<a id="comparison"></a>

### Comparison

Value comparison

**Code:**
```elixir
a == b
```

**Expanded AST:**
```elixir
{{:., [line: 348, column: 7], [:erlang, :==]}, [line: 348, column: 7],
 [
   {:a, [version: 0, line: 348, column: 5], nil},
   {:b, [version: 1, line: 348, column: 10], nil}
 ]}
```

---

<a id="strict-comparison"></a>

### Strict comparison

Strict equality

**Code:**
```elixir
a === b
```

**Expanded AST:**
```elixir
{{:., [line: 354, column: 7], [:erlang, :"=:="]}, [line: 354, column: 7],
 [
   {:a, [version: 0, line: 354, column: 5], nil},
   {:b, [version: 1, line: 354, column: 11], nil}
 ]}
```

---

<a id="ordering"></a>

### Ordering

Ordering operators

**Code:**
```elixir
a < b and c >= d
```

**Expanded AST:**
```elixir
{:case, [line: 360, optimize_boolean: true, type_check: {:case, :and}],
 [
   {{:., [line: 360, column: 7], [:erlang, :<]}, [line: 360, column: 7],
    [
      {:a, [version: 0, line: 360, column: 5], nil},
      {:b, [version: 1, line: 360, column: 9], nil}
    ]},
   [
     do: [
       {:->, [line: 360], [[false], false]},
       {:->, [line: 360],
        [
          [true],
          {{:., [line: 360, column: 17], [:erlang, :>=]},
           [line: 360, column: 17],
           [
             {:c, [version: 2, line: 360, column: 15], nil},
             {:d, [version: 3, line: 360, column: 20], nil}
           ]}
        ]}
     ]
   ]
 ]}
```

---

<a id="and"></a>

### and

Strict boolean conjunction

**Code:**
```elixir
a and b
```

**Expanded AST:**
```elixir
{:case, [line: 366, optimize_boolean: true, type_check: {:case, :and}],
 [
   {:a, [version: 0, line: 366, column: 5], nil},
   [
     do: [
       {:->, [line: 366], [[false], false]},
       {:->, [line: 366],
        [[true], {:b, [version: 1, line: 366, column: 11], nil}]},
       {:->, [line: 366, generated: true],
        [
          [
            {:other,
             [
               version: 2,
               line: 366,
               counter: {Dx.Dev.ElixirSyntaxReference, 557},
               generated: true
             ], Kernel}
          ],
          {{:., [line: 366, generated: true], [:erlang, :error]},
           [line: 366, generated: true],
           [
             {:{}, [line: 366, generated: true],
              [
                :badbool,
                :and,
                {:other,
                 [
                   version: 2,
                   line: 366,
                   counter: {Dx.Dev.ElixirSyntaxReference, 557},
                   generated: true
                 ], Kernel}
              ]}
           ]}
        ]}
     ]
   ]
 ]}
```

---

<a id="or"></a>

### or

Strict boolean disjunction

**Code:**
```elixir
a or b
```

**Expanded AST:**
```elixir
{:case, [line: 372, optimize_boolean: true, type_check: {:case, :or}],
 [
   {:a, [version: 0, line: 372, column: 5], nil},
   [
     do: [
       {:->, [line: 372],
        [[false], {:b, [version: 1, line: 372, column: 10], nil}]},
       {:->, [line: 372], [[true], true]},
       {:->, [line: 372, generated: true],
        [
          [
            {:other,
             [
               version: 2,
               line: 372,
               counter: {Dx.Dev.ElixirSyntaxReference, 558},
               generated: true
             ], Kernel}
          ],
          {{:., [line: 372, generated: true], [:erlang, :error]},
           [line: 372, generated: true],
           [
             {:{}, [line: 372, generated: true],
              [
                :badbool,
                :or,
                {:other,
                 [
                   version: 2,
                   line: 372,
                   counter: {Dx.Dev.ElixirSyntaxReference, 558},
                   generated: true
                 ], Kernel}
              ]}
           ]}
        ]}
     ]
   ]
 ]}
```

---

<a id="not"></a>

### not

Strict boolean negation

**Code:**
```elixir
not a
```

**Expanded AST:**
```elixir
{{:., [line: 378, column: 5], [:erlang, :not]}, [line: 378, column: 5],
 [{:a, [version: 0, line: 378, column: 9], nil}]}
```

---

<a id="operator-and-and"></a>

### &&

Truthy/falsy conjunction

**Code:**
```elixir
a && b
```

**Expanded AST:**
```elixir
{:case, [line: 384, type_check: {:case, :&&}],
 [
   {:a, [version: 0, line: 384, column: 5], nil},
   [
     do: [
       {:->, [line: 384],
        [
          [
            {:when, [line: 384],
             [
               {:x,
                [
                  version: 2,
                  line: 384,
                  counter: {Dx.Dev.ElixirSyntaxReference, 559}
                ], Kernel},
               {{:., [line: 384, generated: true], [:erlang, :orelse]},
                [line: 384, generated: true],
                [
                  {{:., [line: 384, generated: true], [:erlang, :"=:="]},
                   [line: 384, generated: true],
                   [
                     {:x,
                      [
                        version: 2,
                        line: 384,
                        counter: {Dx.Dev.ElixirSyntaxReference, 559},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 384, generated: true], [:erlang, :"=:="]},
                   [line: 384, generated: true],
                   [
                     {:x,
                      [
                        version: 2,
                        line: 384,
                        counter: {Dx.Dev.ElixirSyntaxReference, 559},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          {:x,
           [version: 2, line: 384, counter: {Dx.Dev.ElixirSyntaxReference, 559}],
           Kernel}
        ]},
       {:->, [line: 384],
        [
          [{:_, [line: 384], Kernel}],
          {:b, [version: 1, line: 384, column: 10], nil}
        ]}
     ]
   ]
 ]}
```

---

<a id="operator-or-or"></a>

### ||

Truthy/falsy disjunction

**Code:**
```elixir
a || b
```

**Expanded AST:**
```elixir
{:case, [line: 390, type_check: {:case, :||}],
 [
   {:a, [version: 0, line: 390, column: 5], nil},
   [
     do: [
       {:->, [line: 390],
        [
          [
            {:when, [line: 390],
             [
               {:x,
                [
                  version: 2,
                  line: 390,
                  counter: {Dx.Dev.ElixirSyntaxReference, 560}
                ], Kernel},
               {{:., [line: 390, generated: true], [:erlang, :orelse]},
                [line: 390, generated: true],
                [
                  {{:., [line: 390, generated: true], [:erlang, :"=:="]},
                   [line: 390, generated: true],
                   [
                     {:x,
                      [
                        version: 2,
                        line: 390,
                        counter: {Dx.Dev.ElixirSyntaxReference, 560},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 390, generated: true], [:erlang, :"=:="]},
                   [line: 390, generated: true],
                   [
                     {:x,
                      [
                        version: 2,
                        line: 390,
                        counter: {Dx.Dev.ElixirSyntaxReference, 560},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          {:b, [version: 1, line: 390, column: 10], nil}
        ]},
       {:->, [line: 390],
        [
          [
            {:x,
             [
               version: 3,
               line: 390,
               counter: {Dx.Dev.ElixirSyntaxReference, 560}
             ], Kernel}
          ],
          {:x,
           [version: 3, line: 390, counter: {Dx.Dev.ElixirSyntaxReference, 560}],
           Kernel}
        ]}
     ]
   ]
 ]}
```

---

<a id="operator-bang"></a>

### !

Truthy/falsy negation

**Code:**
```elixir
!a
```

**Expanded AST:**
```elixir
{:case, [line: 396, optimize_boolean: true, type_check: {:case, :!}],
 [
   {:a, [version: 0, line: 396, column: 6], nil},
   [
     do: [
       {:->, [line: 396],
        [
          [
            {:when, [line: 396],
             [
               {:x,
                [
                  version: 1,
                  line: 396,
                  counter: {Dx.Dev.ElixirSyntaxReference, 561}
                ], Kernel},
               {{:., [line: 396, generated: true], [:erlang, :orelse]},
                [line: 396, generated: true],
                [
                  {{:., [line: 396, generated: true], [:erlang, :"=:="]},
                   [line: 396, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 396,
                        counter: {Dx.Dev.ElixirSyntaxReference, 561},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 396, generated: true], [:erlang, :"=:="]},
                   [line: 396, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 396,
                        counter: {Dx.Dev.ElixirSyntaxReference, 561},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          true
        ]},
       {:->, [line: 396], [[{:_, [line: 396], Kernel}], false]}
     ]
   ]
 ]}
```

---

<a id="boolean-strict"></a>

### Boolean (strict)

Strict boolean operators

**Code:**
```elixir
a and b or not c
```

**Expanded AST:**
```elixir
{:case, [line: 402, optimize_boolean: true, type_check: {:case, :or}],
 [
   {:case, [line: 402, optimize_boolean: true, type_check: {:case, :and}],
    [
      {:a, [version: 0, line: 402, column: 6], nil},
      [
        do: [
          {:->, [line: 402], [[false], false]},
          {:->, [line: 402],
           [[true], {:b, [version: 1, line: 402, column: 12], nil}]},
          {:->, [line: 402, generated: true],
           [
             [
               {:other,
                [
                  version: 3,
                  line: 402,
                  counter: {Dx.Dev.ElixirSyntaxReference, 563},
                  generated: true
                ], Kernel}
             ],
             {{:., [line: 402, generated: true], [:erlang, :error]},
              [line: 402, generated: true],
              [
                {:{}, [line: 402, generated: true],
                 [
                   :badbool,
                   :and,
                   {:other,
                    [
                      version: 3,
                      line: 402,
                      counter: {Dx.Dev.ElixirSyntaxReference, 563},
                      generated: true
                    ], Kernel}
                 ]}
              ]}
           ]}
        ]
      ]
    ]},
   [
     do: [
       {:->, [line: 402],
        [
          [false],
          {{:., [line: 402, column: 18], [:erlang, :not]},
           [line: 402, column: 18],
           [{:c, [version: 2, line: 402, column: 22], nil}]}
        ]},
       {:->, [line: 402], [[true], true]},
       {:->, [line: 402, generated: true],
        [
          [
            {:other,
             [
               version: 4,
               line: 402,
               counter: {Dx.Dev.ElixirSyntaxReference, 562},
               generated: true
             ], Kernel}
          ],
          {{:., [line: 402, generated: true], [:erlang, :error]},
           [line: 402, generated: true],
           [
             {:{}, [line: 402, generated: true],
              [
                :badbool,
                :or,
                {:other,
                 [
                   version: 4,
                   line: 402,
                   counter: {Dx.Dev.ElixirSyntaxReference, 562},
                   generated: true
                 ], Kernel}
              ]}
           ]}
        ]}
     ]
   ]
 ]}
```

---

<a id="boolean-relaxed"></a>

### Boolean (relaxed)

Truthy/falsy boolean operators

**Code:**
```elixir
a && b || !c
```

**Expanded AST:**
```elixir
{:case, [line: 408, type_check: {:case, :||}],
 [
   {:case, [line: 408, type_check: {:case, :&&}],
    [
      {:a, [version: 0, line: 408, column: 6], nil},
      [
        do: [
          {:->, [line: 408],
           [
             [
               {:when, [line: 408],
                [
                  {:x,
                   [
                     version: 3,
                     line: 408,
                     counter: {Dx.Dev.ElixirSyntaxReference, 565}
                   ], Kernel},
                  {{:., [line: 408, generated: true], [:erlang, :orelse]},
                   [line: 408, generated: true],
                   [
                     {{:., [line: 408, generated: true], [:erlang, :"=:="]},
                      [line: 408, generated: true],
                      [
                        {:x,
                         [
                           version: 3,
                           line: 408,
                           counter: {Dx.Dev.ElixirSyntaxReference, 565},
                           generated: true
                         ], Kernel},
                        false
                      ]},
                     {{:., [line: 408, generated: true], [:erlang, :"=:="]},
                      [line: 408, generated: true],
                      [
                        {:x,
                         [
                           version: 3,
                           line: 408,
                           counter: {Dx.Dev.ElixirSyntaxReference, 565},
                           generated: true
                         ], Kernel},
                        nil
                      ]}
                   ]}
                ]}
             ],
             {:x,
              [
                version: 3,
                line: 408,
                counter: {Dx.Dev.ElixirSyntaxReference, 565}
              ], Kernel}
           ]},
          {:->, [line: 408],
           [
             [{:_, [line: 408], Kernel}],
             {:b, [version: 1, line: 408, column: 11], nil}
           ]}
        ]
      ]
    ]},
   [
     do: [
       {:->, [line: 408],
        [
          [
            {:when, [line: 408],
             [
               {:x,
                [
                  version: 4,
                  line: 408,
                  counter: {Dx.Dev.ElixirSyntaxReference, 564}
                ], Kernel},
               {{:., [line: 408, generated: true], [:erlang, :orelse]},
                [line: 408, generated: true],
                [
                  {{:., [line: 408, generated: true], [:erlang, :"=:="]},
                   [line: 408, generated: true],
                   [
                     {:x,
                      [
                        version: 4,
                        line: 408,
                        counter: {Dx.Dev.ElixirSyntaxReference, 564},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 408, generated: true], [:erlang, :"=:="]},
                   [line: 408, generated: true],
                   [
                     {:x,
                      [
                        version: 4,
                        line: 408,
                        counter: {Dx.Dev.ElixirSyntaxReference, 564},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          {:case, [line: 408, optimize_boolean: true, type_check: {:case, :!}],
           [
             {:c, [version: 2, line: 408, column: 18], nil},
             [
               do: [
                 {:->, [line: 408],
                  [
                    [
                      {:when, [line: 408],
                       [
                         {:x,
                          [
                            version: 5,
                            line: 408,
                            counter: {Dx.Dev.ElixirSyntaxReference, 566}
                          ], Kernel},
                         {{:., [line: 408, generated: true], [:erlang, :orelse]},
                          [line: 408, generated: true],
                          [
                            {{:., [line: 408, generated: true],
                              [:erlang, :"=:="]}, [line: 408, generated: true],
                             [
                               {:x,
                                [
                                  version: 5,
                                  line: 408,
                                  counter: {Dx.Dev.ElixirSyntaxReference, 566},
                                  generated: true
                                ], Kernel},
                               false
                             ]},
                            {{:., [line: 408, generated: true],
                              [:erlang, :"=:="]}, [line: 408, generated: true],
                             [
                               {:x,
                                [
                                  version: 5,
                                  line: 408,
                                  counter: {Dx.Dev.ElixirSyntaxReference, 566},
                                  generated: true
                                ], Kernel},
                               nil
                             ]}
                          ]}
                       ]}
                    ],
                    true
                  ]},
                 {:->, [line: 408], [[{:_, [line: 408], Kernel}], false]}
               ]
             ]
           ]}
        ]},
       {:->, [line: 408],
        [
          [
            {:x,
             [
               version: 6,
               line: 408,
               counter: {Dx.Dev.ElixirSyntaxReference, 564}
             ], Kernel}
          ],
          {:x,
           [version: 6, line: 408, counter: {Dx.Dev.ElixirSyntaxReference, 564}],
           Kernel}
        ]}
     ]
   ]
 ]}
```

---

<a id="string-concat"></a>

### String concat

Binary concatenation

**Code:**
```elixir
"hello" <> " " <> "world"
```

**Expanded AST:**
```elixir
{:<<>>, [alignment: 0, line: 413],
 [
   {:"::", [inferred_bitstring_spec: true, line: 413],
    ["hello", {:binary, [line: 413], nil}]},
   {:"::", [inferred_bitstring_spec: true, line: 413],
    [" ", {:binary, [line: 413], nil}]},
   {:"::", [inferred_bitstring_spec: true, line: 413],
    ["world", {:binary, [line: 413], nil}]}
 ]}
```

---

<a id="list-concat"></a>

### List concat

List concatenation

**Code:**
```elixir
[1, 2] ++ [3, 4]
```

**Expanded AST:**
```elixir
{{:., [line: 417, column: 12], [:erlang, :++]}, [line: 417, column: 12],
 [[1, 2], [3, 4]]}
```

---

<a id="list-subtract"></a>

### List subtract

List subtraction

**Code:**
```elixir
[1, 2, 3] -- [2]
```

**Expanded AST:**
```elixir
{{:., [line: 421, column: 15], [:erlang, :--]}, [line: 421, column: 15],
 [[1, 2, 3], [2]]}
```

---

<a id="match"></a>

### Match

Pattern match

**Code:**
```elixir
{a, b} = tuple
```

**Expanded AST:**
```elixir
{:__block__, [line: 426, column: 19],
 [
   {:=, [line: 427, column: 12],
    [
      {{:a, [version: 1, line: 427, column: 6], nil},
       {:b, [version: 2, line: 427, column: 9], nil}},
      {:tuple, [version: 0, line: 427, column: 14], nil}
    ]},
   {{:a, [version: 1, line: 428, column: 6], nil},
    {:b, [version: 2, line: 428, column: 9], nil}}
 ]}
```

---

<a id="pin"></a>

### Pin

Pinned pattern match

**Code:**
```elixir
^existing = value
```

**Expanded AST:**
```elixir
{:=, [line: 434, column: 15],
 [
   {:^, [line: 434, column: 5],
    [{:existing, [version: 0, line: 434, column: 6], nil}]},
   {:value, [version: 1, line: 434, column: 17], nil}
 ]}
```

---

<a id="pipe"></a>

### Pipe

Pipeline operator

**Code:**
```elixir
value |> function()
```

**Expanded AST:**
```elixir
{:function, [line: 440, column: 14],
 [{:value, [version: 0, line: 440, column: 5], nil}]}
```

---

<a id="capture-named"></a>

### Capture (named)

Remote function capture

**Code:**
```elixir
&String.upcase/1
```

**Expanded AST:**
```elixir
{:&, [line: 444, column: 5],
 [
   {:/, [],
    [
      {{:., [line: 444, column: 12], [String, :upcase]},
       [no_parens: true, line: 444, column: 13], []},
      1
    ]}
 ]}
```

---

<a id="capture-anonymous"></a>

### Capture (anonymous)

Anonymous capture

**Code:**
```elixir
&(&1 + &2)
```

**Expanded AST:**
```elixir
{:&, [line: 448, column: 5],
 [
   {:/, [],
    [
      {{:., [line: 448, column: 10], [:erlang, :+]}, [line: 448, column: 10],
       []},
      2
    ]}
 ]}
```

---

<a id="access"></a>

### Access

Bracket access

**Code:**
```elixir
data[:key]
```

**Expanded AST:**
```elixir
{{:., [from_brackets: true, line: 454, column: 9], [Access, :get]},
 [from_brackets: true, line: 454, column: 9],
 [{:data, [version: 0, line: 454, column: 5], nil}, :key]}
```

---

<a id="membership"></a>

### Membership

Membership operator

**Code:**
```elixir
x in [1, 2, 3]
```

**Expanded AST:**
```elixir
{{:., [line: 460], [:lists, :member]}, [line: 460],
 [{:x, [version: 0, line: 460, column: 5], nil}, [1, 2, 3]]}
```

---

<a id="ternary-like"></a>

### Ternary-like

Inline conditional

**Code:**
```elixir
if(condition, do: a, else: b)
```

**Expanded AST:**
```elixir
{:case, [line: 466, optimize_boolean: true, type_check: {:case, :if}],
 [
   {:condition, [version: 0, line: 466, column: 8], nil},
   [
     do: [
       {:->, [line: 466],
        [
          [
            {:when, [line: 466],
             [
               {:x,
                [
                  version: 3,
                  line: 466,
                  counter: {Dx.Dev.ElixirSyntaxReference, 570}
                ], Kernel},
               {{:., [line: 466, generated: true], [:erlang, :orelse]},
                [line: 466, generated: true],
                [
                  {{:., [line: 466, generated: true], [:erlang, :"=:="]},
                   [line: 466, generated: true],
                   [
                     {:x,
                      [
                        version: 3,
                        line: 466,
                        counter: {Dx.Dev.ElixirSyntaxReference, 570},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 466, generated: true], [:erlang, :"=:="]},
                   [line: 466, generated: true],
                   [
                     {:x,
                      [
                        version: 3,
                        line: 466,
                        counter: {Dx.Dev.ElixirSyntaxReference, 570},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          {:b, [version: 2, line: 466, column: 32], nil}
        ]},
       {:->, [line: 466],
        [
          [{:_, [line: 466], Kernel}],
          {:a, [version: 1, line: 466, column: 23], nil}
        ]}
     ]
   ]
 ]}
```

## Pattern Matching

<a id="variable-binding"></a>

### Variable binding

Variable binding

**Code:**
```elixir
x = 42
```

**Expanded AST:**
```elixir
{:__block__, [line: 469, column: 85],
 [
   {:=, [line: 470, column: 7],
    [{:x, [version: 0, line: 470, column: 5], nil}, 42]},
   {:x, [version: 0, line: 471, column: 5], nil}
 ]}
```

---

<a id="tuple-destructure"></a>

### Tuple destructure

Tuple destructuring

**Code:**
```elixir
{a, b, c} = tuple
```

**Expanded AST:**
```elixir
{:__block__, [line: 476, column: 19],
 [
   {:=, [line: 477, column: 15],
    [
      {:{}, [line: 477, column: 5],
       [
         {:a, [version: 1, line: 477, column: 6], nil},
         {:b, [version: 2, line: 477, column: 9], nil},
         {:c, [version: 3, line: 477, column: 12], nil}
       ]},
      {:tuple, [version: 0, line: 477, column: 17], nil}
    ]},
   {:{}, [line: 478, column: 5],
    [
      {:a, [version: 1, line: 478, column: 6], nil},
      {:b, [version: 2, line: 478, column: 9], nil},
      {:c, [version: 3, line: 478, column: 12], nil}
    ]}
 ]}
```

---

<a id="list-destructure"></a>

### List destructure

List destructuring

**Code:**
```elixir
[first, second | rest] = list
```

**Expanded AST:**
```elixir
{:__block__, [line: 483, column: 18],
 [
   {:=, [line: 484, column: 28],
    [
      [
        {:first, [version: 1, line: 484, column: 6], nil},
        {:|, [line: 484, column: 20],
         [
           {:second, [version: 2, line: 484, column: 13], nil},
           {:rest, [version: 3, line: 484, column: 22], nil}
         ]}
      ],
      {:list, [version: 0, line: 484, column: 30], nil}
    ]},
   {:{}, [line: 485, column: 5],
    [
      {:first, [version: 1, line: 485, column: 6], nil},
      {:second, [version: 2, line: 485, column: 13], nil},
      {:rest, [version: 3, line: 485, column: 21], nil}
    ]}
 ]}
```

---

<a id="map-destructure"></a>

### Map destructure

Map destructuring

**Code:**
```elixir
%{name: name} = map
```

**Expanded AST:**
```elixir
{:__block__, [line: 490, column: 17],
 [
   {:=, [line: 491, column: 19],
    [
      {:%{}, [line: 491, column: 5],
       [name: {:name, [version: 1, line: 491, column: 13], nil}]},
      {:map, [version: 0, line: 491, column: 21], nil}
    ]},
   {:name, [version: 1, line: 492, column: 5], nil}
 ]}
```

---

<a id="struct-destructure"></a>

### Struct destructure

Struct destructuring

**Code:**
```elixir
%User{name: name} = user
```

**Expanded AST:**
```elixir
{:__block__, [line: 497, column: 18],
 [
   {:=, [line: 498, column: 52],
    [
      {:%, [line: 498, column: 5],
       [
         Dx.Dev.ElixirSyntaxReference.User,
         {:%{}, [line: 498, column: 39],
          [name: {:name, [version: 1, line: 498, column: 46], nil}]}
       ]},
      {:user, [version: 0, line: 498, column: 54], nil}
    ]},
   {:name, [version: 1, line: 499, column: 5], nil}
 ]}
```

---

<a id="pin-in-pattern"></a>

### Pin in pattern

Pinned value inside pattern

**Code:**
```elixir
{^key, value} = tuple
```

**Expanded AST:**
```elixir
{:__block__, [line: 504, column: 24],
 [
   {:=, [line: 505, column: 19],
    [
      {{:^, [line: 505, column: 6],
        [{:key, [version: 0, line: 505, column: 7], nil}]},
       {:value, [version: 2, line: 505, column: 12], nil}},
      {:tuple, [version: 1, line: 505, column: 21], nil}
    ]},
   {:value, [version: 2, line: 506, column: 5], nil}
 ]}
```

---

<a id="binary-pattern"></a>

### Binary pattern

Binary pattern match

**Code:**
```elixir
<<header::binary-size(4), rest::binary>> = data
```

**Expanded AST:**
```elixir
{:__block__, [line: 511, column: 18],
 [
   {:=, [line: 512, column: 46],
    [
      {:<<>>, [alignment: 0, line: 512, column: 5],
       [
         {:"::", [line: 512, column: 13],
          [
            {:header, [version: 1, line: 512, column: 7], nil},
            {:-, [line: 512, column: 13],
             [{:binary, [], nil}, {:size, [], [4]}]}
          ]},
         {:"::", [line: 512, column: 35],
          [
            {:rest, [version: 2, line: 512, column: 31], nil},
            {:binary, [], nil}
          ]}
       ]},
      {:data, [version: 0, line: 512, column: 48], nil}
    ]},
   {{:header, [version: 1, line: 513, column: 6], nil},
    {:rest, [version: 2, line: 513, column: 14], nil}}
 ]}
```

---

<a id="ignore-value"></a>

### Ignore value

Discarded pattern value

**Code:**
```elixir
{_, value} = tuple
```

**Expanded AST:**
```elixir
{:__block__, [line: 518, column: 19],
 [
   {:=, [line: 519, column: 16],
    [
      {{:_, [line: 519, column: 6], nil},
       {:value, [version: 1, line: 519, column: 9], nil}},
      {:tuple, [version: 0, line: 519, column: 18], nil}
    ]},
   {:value, [version: 1, line: 520, column: 5], nil}
 ]}
```

---

<a id="named-ignore"></a>

### Named ignore

Named ignored pattern value

**Code:**
```elixir
{_ignored, value} = tuple
```

**Expanded AST:**
```elixir
{:__block__, [line: 525, column: 19],
 [
   {:=, [line: 526, column: 23],
    [
      {{:_ignored, [version: 1, line: 526, column: 6], nil},
       {:value, [version: 2, line: 526, column: 16], nil}},
      {:tuple, [version: 0, line: 526, column: 25], nil}
    ]},
   {:value, [version: 2, line: 527, column: 5], nil}
 ]}
```

## Control Flow

<a id="case"></a>

### case

Pattern match branch

**Code:**
```elixir
case x do
  {:ok, val} -> val
  {:error, _} -> nil
end
```

**Expanded AST:**
```elixir
{:case, [line: 538, column: 5],
 [
   {:x, [version: 0, line: 538, column: 10], nil},
   [
     do: [
       {:->, [line: 539, column: 18],
        [
          [ok: {:val, [version: 1, line: 539, column: 13], nil}],
          {:val, [version: 1, line: 539, column: 21], nil}
        ]},
       {:->, [line: 540, column: 19],
        [[error: {:_, [line: 540, column: 16], nil}], nil]}
     ]
   ]
 ]}
```

---

<a id="case-guard"></a>

### case (guard)

Case branch with guards

**Code:**
```elixir
case x do
  n when n > 0 -> :positive
  n when n < 0 -> :negative
  _ -> :zero
end
```

**Expanded AST:**
```elixir
{:case, [line: 553, column: 5],
 [
   {:x, [version: 0, line: 553, column: 10], nil},
   [
     do: [
       {:->, [line: 554, column: 20],
        [
          [
            {:when, [line: 554, column: 9],
             [
               {:n, [version: 1, line: 554, column: 7], nil},
               {{:., [line: 554, column: 16], [:erlang, :>]},
                [line: 554, column: 16],
                [{:n, [version: 1, line: 554, column: 14], nil}, 0]}
             ]}
          ],
          :positive
        ]},
       {:->, [line: 555, column: 20],
        [
          [
            {:when, [line: 555, column: 9],
             [
               {:n, [version: 2, line: 555, column: 7], nil},
               {{:., [line: 555, column: 16], [:erlang, :<]},
                [line: 555, column: 16],
                [{:n, [version: 2, line: 555, column: 14], nil}, 0]}
             ]}
          ],
          :negative
        ]},
       {:->, [line: 556, column: 9],
        [[{:_, [line: 556, column: 7], nil}], :zero]}
     ]
   ]
 ]}
```

---

<a id="cond"></a>

### cond

Multiple conditional branches

**Code:**
```elixir
cond do
  x > 0 -> :positive
  x < 0 -> :negative
  true -> :zero
end
```

**Expanded AST:**
```elixir
{:cond, [line: 569, column: 5],
 [
   [
     do: [
       {:->, [line: 570, column: 13],
        [
          [
            {{:., [line: 570, column: 9], [:erlang, :>]},
             [line: 570, column: 9],
             [{:x, [version: 0, line: 570, column: 7], nil}, 0]}
          ],
          :positive
        ]},
       {:->, [line: 571, column: 13],
        [
          [
            {{:., [line: 571, column: 9], [:erlang, :<]},
             [line: 571, column: 9],
             [{:x, [version: 0, line: 571, column: 7], nil}, 0]}
          ],
          :negative
        ]},
       {:->, [line: 572, column: 12], [[true], :zero]}
     ]
   ]
 ]}
```

---

<a id="if"></a>

### if

Conditional branch

**Code:**
```elixir
if condition do
  :yes
else
  :no
end
```

**Expanded AST:**
```elixir
{:case, [line: 585, optimize_boolean: true, type_check: {:case, :if}],
 [
   {:condition, [version: 0, line: 585, column: 8], nil},
   [
     do: [
       {:->, [line: 585],
        [
          [
            {:when, [line: 585],
             [
               {:x,
                [
                  version: 1,
                  line: 585,
                  counter: {Dx.Dev.ElixirSyntaxReference, 571}
                ], Kernel},
               {{:., [line: 585, generated: true], [:erlang, :orelse]},
                [line: 585, generated: true],
                [
                  {{:., [line: 585, generated: true], [:erlang, :"=:="]},
                   [line: 585, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 585,
                        counter: {Dx.Dev.ElixirSyntaxReference, 571},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 585, generated: true], [:erlang, :"=:="]},
                   [line: 585, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 585,
                        counter: {Dx.Dev.ElixirSyntaxReference, 571},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          :no
        ]},
       {:->, [line: 585], [[{:_, [line: 585], Kernel}], :yes]}
     ]
   ]
 ]}
```

---

<a id="if-inline"></a>

### if (inline)

Inline conditional

**Code:**
```elixir
if condition, do: :yes, else: :no
```

**Expanded AST:**
```elixir
{:case, [line: 595, optimize_boolean: true, type_check: {:case, :if}],
 [
   {:condition, [version: 0, line: 595, column: 8], nil},
   [
     do: [
       {:->, [line: 595],
        [
          [
            {:when, [line: 595],
             [
               {:x,
                [
                  version: 1,
                  line: 595,
                  counter: {Dx.Dev.ElixirSyntaxReference, 572}
                ], Kernel},
               {{:., [line: 595, generated: true], [:erlang, :orelse]},
                [line: 595, generated: true],
                [
                  {{:., [line: 595, generated: true], [:erlang, :"=:="]},
                   [line: 595, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 595,
                        counter: {Dx.Dev.ElixirSyntaxReference, 572},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 595, generated: true], [:erlang, :"=:="]},
                   [line: 595, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 595,
                        counter: {Dx.Dev.ElixirSyntaxReference, 572},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          :no
        ]},
       {:->, [line: 595], [[{:_, [line: 595], Kernel}], :yes]}
     ]
   ]
 ]}
```

---

<a id="unless"></a>

### unless

Negated conditional

**Code:**
```elixir
unless condition do
  :not_condition
end
```

**Expanded AST:**
```elixir
{:case, [line: 605, optimize_boolean: true, type_check: {:case, :unless}],
 [
   {:condition, [version: 0, line: 605, column: 12], nil},
   [
     do: [
       {:->, [line: 605],
        [
          [
            {:when, [line: 605],
             [
               {:x,
                [
                  version: 1,
                  line: 605,
                  counter: {Dx.Dev.ElixirSyntaxReference, 573}
                ], Kernel},
               {{:., [line: 605, generated: true], [:erlang, :orelse]},
                [line: 605, generated: true],
                [
                  {{:., [line: 605, generated: true], [:erlang, :"=:="]},
                   [line: 605, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 605,
                        counter: {Dx.Dev.ElixirSyntaxReference, 573},
                        generated: true
                      ], Kernel},
                     false
                   ]},
                  {{:., [line: 605, generated: true], [:erlang, :"=:="]},
                   [line: 605, generated: true],
                   [
                     {:x,
                      [
                        version: 1,
                        line: 605,
                        counter: {Dx.Dev.ElixirSyntaxReference, 573},
                        generated: true
                      ], Kernel},
                     nil
                   ]}
                ]}
             ]}
          ],
          :not_condition
        ]},
       {:->, [line: 605], [[{:_, [line: 605], Kernel}], nil]}
     ]
   ]
 ]}
```

---

<a id="with"></a>

### with

Happy path chaining

**Code:**
```elixir
with {:ok, a} <- fetch_a(),
     {:ok, b} <- fetch_b(a) do
  {:ok, a + b}
end
```

**Expanded AST:**
```elixir
{:with, [line: 617, column: 5],
 [
   {:<-, [line: 617, column: 19],
    [
      {:ok, {:a, [version: 0, line: 617, column: 16], nil}},
      {:fetch_a, [line: 617, column: 22], []}
    ]},
   {:<-, [line: 618, column: 19],
    [
      {:ok, {:b, [version: 1, line: 618, column: 16], nil}},
      {:fetch_b, [line: 618, column: 22],
       [{:a, [version: 0, line: 618, column: 30], nil}]}
    ]},
   [
     do: {:ok,
      {{:., [line: 619, column: 15], [:erlang, :+]}, [line: 619, column: 15],
       [
         {:a, [version: 0, line: 619, column: 13], nil},
         {:b, [version: 1, line: 619, column: 17], nil}
       ]}}
   ]
 ]}
```

---

<a id="with-else"></a>

### with (else)

With fallback clauses

**Code:**
```elixir
with {:ok, val} <- fetch() do
  val
else
  {:error, reason} -> reason
  _ -> :unknown
end
```

**Expanded AST:**
```elixir
{:with, [line: 632, column: 5],
 [
   {:<-, [line: 632, column: 21],
    [
      {:ok, {:val, [version: 0, line: 632, column: 16], nil}},
      {:fetch, [line: 632, column: 24], []}
    ]},
   [
     do: {:val, [version: 0, line: 633, column: 7], nil},
     else: [
       {:->, [line: 635, column: 24],
        [
          [error: {:reason, [version: 1, line: 635, column: 16], nil}],
          {:reason, [version: 1, line: 635, column: 27], nil}
        ]},
       {:->, [line: 636, column: 9],
        [[{:_, [line: 636, column: 7], nil}], :unknown]}
     ]
   ]
 ]}
```

## Error Handling

<a id="tryrescue"></a>

### try/rescue

Rescue exceptions

**Code:**
```elixir
try do
  risky()
rescue
  e in RuntimeError -> e.message
end
```

**Expanded AST:**
```elixir
{:try, [line: 648, column: 5],
 [
   [
     do: {:risky, [line: 649, column: 7], []},
     rescue: [
       {:->, [line: 651, column: 25],
        [
          [
            {:in, [line: 651, column: 9],
             [{:e, [version: 0, line: 651, column: 7], nil}, [RuntimeError]]}
          ],
          {{:., [line: 651, column: 29],
            [{:e, [version: 0, line: 651, column: 28], nil}, :message]},
           [no_parens: true, line: 651, column: 30], []}
        ]}
     ]
   ]
 ]}
```

---

<a id="trycatch"></a>

### try/catch

Catch thrown values

**Code:**
```elixir
try do
  throw(:ball)
catch
  :throw, val -> val
end
```

**Expanded AST:**
```elixir
{:try, [line: 663, column: 5],
 [
   [
     do: {{:., [line: 664, column: 7], [:erlang, :throw]},
      [line: 664, column: 7], [:ball]},
     catch: [
       {:->, [line: 666, column: 19],
        [
          [:throw, {:val, [version: 0, line: 666, column: 15], nil}],
          {:val, [version: 0, line: 666, column: 22], nil}
        ]}
     ]
   ]
 ]}
```

---

<a id="tryafter"></a>

### try/after

After cleanup clause

**Code:**
```elixir
try do
  open()
after
  close()
end
```

**Expanded AST:**
```elixir
{:try, [line: 678, column: 5],
 [
   [
     do: {:open, [line: 679, column: 7], []},
     after: {:close, [line: 681, column: 7], []}
   ]
 ]}
```

---

<a id="raise"></a>

### raise

Raise with message

**Code:**
```elixir
raise "error message"
```

**Expanded AST:**
```elixir
{{:., [line: 686], [:erlang, :error]}, [line: 686],
 [
   {{:., [line: 686], [RuntimeError, :exception]}, [line: 686],
    ["error message"]},
   :none,
   [error_info: {:%{}, [line: 686], [module: Exception]}]
 ]}
```

---

<a id="raise-struct"></a>

### raise (struct)

Raise with exception struct

**Code:**
```elixir
raise ArgumentError, message: "bad arg"
```

**Expanded AST:**
```elixir
{{:., [line: 691], [:erlang, :error]}, [line: 691],
 [
   {{:., [line: 691], [ArgumentError, :exception]}, [line: 691],
    [[message: "bad arg"]]}
 ]}
```

---

<a id="reraise"></a>

### reraise

Re-raise with stacktrace

**Code:**
```elixir
try do
  risky!()
rescue
  exception -> reraise exception, __STACKTRACE__
end
```

**Expanded AST:**
```elixir
{:try, [line: 702, column: 5],
 [
   [
     do: {:risky!, [line: 703, column: 7], []},
     rescue: [
       {:->, [line: 705, column: 17],
        [
          [{:exception, [version: 0, line: 705, column: 7], nil}],
          {{:., [line: 705], [:erlang, :raise]}, [line: 705],
           [
             :error,
             {{:., [line: 705], [Kernel.Utils, :raise]}, [line: 705],
              [{:exception, [version: 0, line: 705, column: 28], nil}]},
             {:__STACKTRACE__, [line: 705, column: 39], nil}
           ]}
        ]}
     ]
   ]
 ]}
```

---

<a id="throw"></a>

### throw

Throw non-local value

**Code:**
```elixir
throw({:early_exit, value})
```

**Expanded AST:**
```elixir
{{:., [line: 712, column: 5], [:erlang, :throw]}, [line: 712, column: 5],
 [early_exit: {:value, [version: 0, line: 712, column: 25], nil}]}
```

## Functions

<a id="anonymous-fn"></a>

### Anonymous (fn)

Anonymous function

**Code:**
```elixir
fn x -> x * 2 end
```

**Expanded AST:**
```elixir
{:fn, [line: 716, column: 5],
 [
   {:->, [line: 716, column: 10],
    [
      [{:x, [version: 0, line: 716, column: 8], nil}],
      {{:., [line: 716, column: 15], [:erlang, :*]}, [line: 716, column: 15],
       [{:x, [version: 0, line: 716, column: 13], nil}, 2]}
    ]}
 ]}
```

---

<a id="anonymous-multi-clause"></a>

### Anonymous (multi-clause)

Anonymous function with clauses

**Code:**
```elixir
fn
  {:ok, val} -> val
  :error -> nil
end
```

**Expanded AST:**
```elixir
{:fn, [line: 726, column: 5],
 [
   {:->, [line: 727, column: 18],
    [
      [ok: {:val, [version: 0, line: 727, column: 13], nil}],
      {:val, [version: 0, line: 727, column: 21], nil}
    ]},
   {:->, [line: 728, column: 14], [[:error], nil]}
 ]}
```

---

<a id="capture-remote"></a>

### Capture (remote)

Remote function capture

**Code:**
```elixir
&String.upcase/1
```

**Expanded AST:**
```elixir
{:&, [line: 733, column: 5],
 [
   {:/, [],
    [
      {{:., [line: 733, column: 12], [String, :upcase]},
       [no_parens: true, line: 733, column: 13], []},
      1
    ]}
 ]}
```

---

<a id="capture-local"></a>

### Capture (local)

Local function capture

**Code:**
```elixir
&local_fun/1
```

**Expanded AST:**
```elixir
{:&, [line: 737, column: 5],
 [{:/, [], [{:local_fun, [line: 737, column: 6], nil}, 1]}]}
```

---

<a id="capture-partial"></a>

### Capture (partial)

Partial anonymous capture

**Code:**
```elixir
&(&1 + &2 * &3)
```

**Expanded AST:**
```elixir
{:fn, [capture: true, line: 741, column: 10],
 [
   {:->, [line: 741, column: 10],
    [
      [
        {:capture,
         [
           version: 0,
           counter: {Dx.Dev.ElixirSyntaxReference, 577},
           capture: 1,
           line: 741,
           column: 7
         ], nil},
        {:capture,
         [
           version: 1,
           counter: {Dx.Dev.ElixirSyntaxReference, 578},
           capture: 2,
           line: 741,
           column: 12
         ], nil},
        {:capture,
         [
           version: 2,
           counter: {Dx.Dev.ElixirSyntaxReference, 579},
           capture: 3,
           line: 741,
           column: 17
         ], nil}
      ],
      {{:., [line: 741, column: 10], [:erlang, :+]}, [line: 741, column: 10],
       [
         {:capture,
          [
            version: 0,
            counter: {Dx.Dev.ElixirSyntaxReference, 577},
            capture: 1,
            line: 741,
            column: 7
          ], nil},
         {{:., [line: 741, column: 15], [:erlang, :*]}, [line: 741, column: 15],
          [
            {:capture,
             [
               version: 1,
               counter: {Dx.Dev.ElixirSyntaxReference, 578},
               capture: 2,
               line: 741,
               column: 12
             ], nil},
            {:capture,
             [
               version: 2,
               counter: {Dx.Dev.ElixirSyntaxReference, 579},
               capture: 3,
               line: 741,
               column: 17
             ], nil}
          ]}
       ]}
    ]}
 ]}
```

---

<a id="function-call"></a>

### Function call

Anonymous function call

**Code:**
```elixir
fun.(arg1, arg2)
```

**Expanded AST:**
```elixir
{{:., [line: 747, column: 8], [{:fun, [version: 0, line: 747, column: 5], nil}]},
 [line: 747, column: 8],
 [
   {:arg1, [version: 1, line: 747, column: 10], nil},
   {:arg2, [version: 2, line: 747, column: 16], nil}
 ]}
```

## Comprehensions

<a id="for-basic"></a>

### for (basic)

Simple comprehension

**Code:**
```elixir
for x <- list, do: x * 2
```

**Expanded AST:**
```elixir
{:for, [line: 753, column: 5],
 [
   {:<-, [line: 753, column: 11],
    [
      {:x, [version: 1, line: 753, column: 9], nil},
      {:list, [version: 0, line: 753, column: 14], nil}
    ]},
   [
     do: {{:., [line: 753, column: 26], [:erlang, :*]}, [line: 753, column: 26],
      [{:x, [version: 1, line: 753, column: 24], nil}, 2]},
     into: []
   ]
 ]}
```

---

<a id="for-filter"></a>

### for (filter)

Comprehension with filter

**Code:**
```elixir
for x <- list, x > 0, do: x
```

**Expanded AST:**
```elixir
{:for, [line: 759, column: 5],
 [
   {:<-, [line: 759, column: 11],
    [
      {:x, [version: 1, line: 759, column: 9], nil},
      {:list, [version: 0, line: 759, column: 14], nil}
    ]},
   {{:., [line: 759, column: 22], [:erlang, :>]}, [line: 759, column: 22],
    [{:x, [version: 1, line: 759, column: 20], nil}, 0]},
   [do: {:x, [version: 1, line: 759, column: 31], nil}, into: []]
 ]}
```

---

<a id="for-multiple"></a>

### for (multiple)

Multiple generators

**Code:**
```elixir
for x <- xs, y <- ys, do: {x, y}
```

**Expanded AST:**
```elixir
{:for, [line: 765, column: 5],
 [
   {:<-, [line: 765, column: 11],
    [
      {:x, [version: 2, line: 765, column: 9], nil},
      {:xs, [version: 0, line: 765, column: 14], nil}
    ]},
   {:<-, [line: 765, column: 20],
    [
      {:y, [version: 3, line: 765, column: 18], nil},
      {:ys, [version: 1, line: 765, column: 23], nil}
    ]},
   [
     do: {{:x, [version: 2, line: 765, column: 32], nil},
      {:y, [version: 3, line: 765, column: 35], nil}},
     into: []
   ]
 ]}
```

---

<a id="for-into"></a>

### for (into)

Comprehension into collector

**Code:**
```elixir
for {k, v} <- map, into: %{}, do: {k, v * 2}
```

**Expanded AST:**
```elixir
{:for, [line: 771, column: 5],
 [
   {:<-, [line: 771, column: 16],
    [
      {{:k, [version: 1, line: 771, column: 10], nil},
       {:v, [version: 2, line: 771, column: 13], nil}},
      {:map, [version: 0, line: 771, column: 19], nil}
    ]},
   [
     do: {{:k, [version: 1, line: 771, column: 40], nil},
      {{:., [line: 771, column: 45], [:erlang, :*]}, [line: 771, column: 45],
       [{:v, [version: 2, line: 771, column: 43], nil}, 2]}},
     into: {:%{}, [line: 771, column: 30], []}
   ]
 ]}
```

---

<a id="for-reduce"></a>

### for (reduce)

Comprehension with accumulator

**Code:**
```elixir
for x <- list, reduce: 0 do
  acc -> acc + x
end
```

**Expanded AST:**
```elixir
{:for, [line: 781, column: 5],
 [
   {:<-, [line: 781, column: 11],
    [
      {:x, [version: 1, line: 781, column: 9], nil},
      {:list, [version: 0, line: 781, column: 14], nil}
    ]},
   [
     do: [
       {:->, [line: 782, column: 11],
        [
          [{:acc, [version: 2, line: 782, column: 7], nil}],
          {{:., [line: 782, column: 18], [:erlang, :+]},
           [line: 782, column: 18],
           [
             {:acc, [version: 2, line: 782, column: 14], nil},
             {:x, [version: 1, line: 782, column: 20], nil}
           ]}
        ]}
     ],
     reduce: 0
   ]
 ]}
```

---

<a id="for-uniq"></a>

### for (uniq)

Unique comprehension results

**Code:**
```elixir
for x <- list, uniq: true, do: x
```

**Expanded AST:**
```elixir
{:for, [line: 789, column: 5],
 [
   {:<-, [line: 789, column: 11],
    [
      {:x, [version: 1, line: 789, column: 9], nil},
      {:list, [version: 0, line: 789, column: 14], nil}
    ]},
   [do: {:x, [version: 1, line: 789, column: 36], nil}, uniq: true, into: []]
 ]}
```

---

<a id="for-binary"></a>

### for (binary)

Binary comprehension

**Code:**
```elixir
for <<byte <- binary>>, do: byte
```

**Expanded AST:**
```elixir
{:for, [line: 795, column: 5],
 [
   {:<<>>, [line: 795, column: 9],
    [
      {:<-, [line: 795, column: 16],
       [
         {:<<>>, [alignment: 0, line: 795, column: 9],
          [
            {:"::", [inferred_bitstring_spec: true, line: 795, column: 11],
             [
               {:byte, [version: 1, line: 795, column: 11], nil},
               {:integer, [line: 795, column: 11], nil}
             ]}
          ]},
         {:binary, [version: 0, line: 795, column: 19], nil}
       ]}
    ]},
   [do: {:byte, [version: 1, line: 795, column: 33], nil}, into: []]
 ]}
```

## Concurrency

<a id="receive"></a>

### receive

Receive message

**Code:**
```elixir
receive do
  {:msg, val} -> val
end
```

**Expanded AST:**
```elixir
{:receive, [line: 804, column: 5],
 [
   [
     do: [
       {:->, [line: 805, column: 19],
        [
          [msg: {:val, [version: 0, line: 805, column: 14], nil}],
          {:val, [version: 0, line: 805, column: 22], nil}
        ]}
     ]
   ]
 ]}
```

---

<a id="receive-after"></a>

### receive (after)

Receive with timeout

**Code:**
```elixir
receive do
  msg -> msg
after
  1000 -> :timeout
end
```

**Expanded AST:**
```elixir
{:receive, [line: 817, column: 5],
 [
   [
     do: [
       {:->, [line: 818, column: 11],
        [
          [{:msg, [version: 0, line: 818, column: 7], nil}],
          {:msg, [version: 0, line: 818, column: 14], nil}
        ]}
     ],
     after: [{:->, [line: 820, column: 12], [[1000], :timeout]}]
   ]
 ]}
```

---

<a id="send"></a>

### send

Send process message

**Code:**
```elixir
send(pid, {:msg, value})
```

**Expanded AST:**
```elixir
{{:., [line: 827, column: 5], [:erlang, :send]}, [line: 827, column: 5],
 [
   {:pid, [version: 0, line: 827, column: 10], nil},
   {:msg, {:value, [version: 1, line: 827, column: 22], nil}}
 ]}
```

---

<a id="spawn"></a>

### spawn

Spawn anonymous function

**Code:**
```elixir
spawn(fn -> work() end)
```

**Expanded AST:**
```elixir
{{:., [line: 831, column: 5], [:erlang, :spawn]}, [line: 831, column: 5],
 [
   {:fn, [line: 831, column: 11],
    [{:->, [line: 831, column: 14], [[], {:work, [line: 831, column: 17], []}]}]}
 ]}
```

---

<a id="spawn-mfa"></a>

### spawn (MFA)

Spawn module-function-args

**Code:**
```elixir
spawn(Module, :function, [args])
```

**Expanded AST:**
```elixir
{{:., [line: 837, column: 5], [:erlang, :spawn]}, [line: 837, column: 5],
 [Module, :function, [{:args, [version: 0, line: 837, column: 31], nil}]]}
```

---

<a id="self"></a>

### self

Current process

**Code:**
```elixir
self()
```

**Expanded AST:**
```elixir
{{:., [line: 841, column: 5], [:erlang, :self]}, [line: 841, column: 5], []}
```

## Metaprogramming

<a id="quote"></a>

### quote

Quoted expression

**Code:**
```elixir
quote do
  1 + 2
end
```

**Expanded AST:**
```elixir
{:{}, [],
 [
   :+,
   [context: Dx.Dev.ElixirSyntaxReference, imports: [{1, Kernel}, {2, Kernel}]],
   [1, 2]
 ]}
```

---

<a id="quote-unquote"></a>

### quote (unquote)

Quoted expression with unquote

**Code:**
```elixir
quote do
  unquote(x) + 1
end
```

**Expanded AST:**
```elixir
{:{}, [],
 [
   :+,
   [context: Dx.Dev.ElixirSyntaxReference, imports: [{1, Kernel}, {2, Kernel}]],
   [
     {{:., [line: 863, column: 7], [:elixir_quote, :shallow_validate_ast]},
      [line: 863, column: 7], [{:x, [version: 0, line: 863, column: 15], nil}]},
     1
   ]
 ]}
```

---

<a id="quote-unquote_splicing"></a>

### quote (unquote_splicing)

Quoted expression with splicing

**Code:**
```elixir
quote do
  [unquote_splicing(list), last]
end
```

**Expanded AST:**
```elixir
{{:., [line: 875, column: 8], [:elixir_quote, :list]}, [line: 875, column: 8],
 [
   {:list, [version: 0, line: 875, column: 25], nil},
   [{:{}, [], [:last, [], Dx.Dev.ElixirSyntaxReference]}]
 ]}
```

---

<a id="__module__"></a>

### __MODULE__

Current module

**Code:**
```elixir
__MODULE__
```

**Expanded AST:**
```elixir
Dx.Dev.ElixirSyntaxReference
```

---

<a id="__env__"></a>

### __ENV__

Current compile environment

**Code:**
```elixir
__ENV__.file
```

**Expanded AST:**
```elixir
"/Users/arno/dev/dx/dev/elixir_syntax_reference.ex"
```

---

<a id="__dir__"></a>

### __DIR__

Current source directory

**Code:**
```elixir
__DIR__
```

**Expanded AST:**
```elixir
"/Users/arno/dev/dx/dev"
```

---

<a id="__caller__"></a>

### __CALLER__

Macro caller environment

**Code:**
```elixir
__CALLER__.line
```

**Expanded AST:**
```elixir
{{:., [line: 894, column: 15],
  [{:__CALLER__, [line: 894, column: 5], nil}, :line]},
 [no_parens: true, line: 894, column: 16], []}
```

---

<a id="__stacktrace__"></a>

### __STACKTRACE__

Current rescue stacktrace

**Code:**
```elixir
try do
  risky!()
rescue
  _ -> __STACKTRACE__
end
```

**Expanded AST:**
```elixir
{:try, [line: 905, column: 5],
 [
   [
     do: {:risky!, [line: 906, column: 7], []},
     rescue: [
       {:->, [line: 908, column: 9],
        [
          [{:_, [line: 908, column: 7], nil}],
          {:__STACKTRACE__, [line: 908, column: 12], nil}
        ]}
     ]
   ]
 ]}
```

## Sigils

<a id="s-string"></a>

### ~s (string)

String sigil

**Code:**
```elixir
~s(hello world)
```

**Expanded AST:**
```elixir
"hello world"
```

---

<a id="s-string-raw"></a>

### ~S (string raw)

Raw string sigil

**Code:**
```elixir
~S(hello\nworld)
```

**Expanded AST:**
```elixir
"hello\\nworld"
```

---

<a id="c-charlist"></a>

### ~c (charlist)

Charlist sigil

**Code:**
```elixir
~c(hello)
```

**Expanded AST:**
```elixir
~c"hello"
```

---

<a id="w-word-list"></a>

### ~w (word list)

Word list sigil

**Code:**
```elixir
~w(foo bar baz)
```

**Expanded AST:**
```elixir
["foo", "bar", "baz"]
```

---

<a id="w-atoms"></a>

### ~w (atoms)

Atom word list sigil

**Code:**
```elixir
~w(foo bar baz)a
```

**Expanded AST:**
```elixir
[:foo, :bar, :baz]
```

---

<a id="r-regex"></a>

### ~r (regex)

Regex sigil

**Code:**
```elixir
~r/pattern/i
```

**Expanded AST:**
```elixir
{:%{}, [line: 933],
 [
   __struct__: Regex,
   re_pattern: {{:., [line: 933], [:re, :import]}, [line: 933],
    [
      {:{}, [line: 933],
       [
         :re_exported_pattern,
         <<114, 101, 45, 80, 67, 82, 69, 50, 150, 151, 112, 131, 1, 0>>,
         "pattern",
         [:export, :caseless],
         <<83, 50, 82, 80, 10, 0, 47, 0, 1, 8, 8, 0, 1, 0, 0, 0, 0, 1, 2, 3, 4,
           5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22,
           23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39,
           40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56,
           57, 58, 59, 60, 61, 62, 63, 64, 97, 98, 99, 100, 101, 102, 103, 104,
           105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118,
           119, 120, 121, 122, 91, 92, 93, 94, 95, 96, 97, 98, 99, 100, 101,
           102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115,
           116, 117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129,
           130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143,
           144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157,
           158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171,
           172, 173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185,
           186, 187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199,
           200, 201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213,
           214, 215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227,
           228, 229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241,
           242, 243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255,
           0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
           20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36,
           37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 53,
           54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 97, 98, 99, 100, 101,
           102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115,
           116, 117, 118, 119, 120, 121, 122, 91, 92, 93, 94, 95, 96, 65, 66,
           67, 68, 69, 70, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83,
           84, 85, 86, 87, 88, 89, 90, 123, 124, 125, 126, 127, 128, 129, 130,
           131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144,
           145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158,
           159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172,
           173, 174, 175, 176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186,
           187, 188, 189, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 200,
           201, 202, 203, 204, 205, 206, 207, 208, 209, 210, 211, 212, 213, 214,
           215, 216, 217, 218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228,
           229, 230, 231, 232, 233, 234, 235, 236, 237, 238, 239, 240, 241, 242,
           243, 244, 245, 246, 247, 248, 249, 250, 251, 252, 253, 254, 255, 0,
           62, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 3, 126, 0, 0, 0, 126,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 255, 3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 254, 255, 255, 7, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 254, 255, 255, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 3, 254, 255, 255, 135, 254,
           255, 255, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 254, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 127, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 255, 255,
           255, 255, 255, 255, 255, 255, 255, 255, 127, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 254, 255, 0, 252, 1, 0, 0, 248,
           1, 0, 0, 120, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255,
           255, 255, 255, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 128, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1,
           1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 24, 24, 24, 24, 24, 24,
           24, 24, 24, 0, 0, 0, 0, 0, 0, 0, 18, 18, 18, 18, 18, 18, 18, 18, 18,
           18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18, 18,
           0, 0, 0, 0, 16, 0, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22,
           22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 22, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
           0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 173, 0, 0, 0, 0,
           0, 0, 0, 152, 0, 0, 0, 0, 0, 0, 0, 69, 82, 67, 80, 8, 0, 0, 0, 8, 0,
           0, 0, 0, 0, 0, 0, 177, 1, 0, 0, 255, 255, 255, 255, 255, 255, 255,
           255, 255, 255, 255, 255, 112, 0, 0, 0, 110, 0, 0, 0, 1, 0, 2, 0, 0,
           0, 7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 0, 0, 0, 0, 0, 0, 0, 137, 0, 17,
           30, 112, 30, 97, 30, 116, 30, 116, 30, 101, 30, 114, 30, 110, 122, 0,
           17, 0>>
       ]}
    ]},
   source: "pattern",
   opts: [:caseless]
 ]}
```

---

<a id="d-date"></a>

### ~D (date)

Date sigil

**Code:**
```elixir
~D[2024-01-15]
```

**Expanded AST:**
```elixir
{:%, [line: 937],
 [
   Date,
   {:%{}, [line: 937], [calendar: Calendar.ISO, year: 2024, month: 1, day: 15]}
 ]}
```

---

<a id="t-time"></a>

### ~T (time)

Time sigil

**Code:**
```elixir
~T[14:30:00]
```

**Expanded AST:**
```elixir
{:%, [line: 941],
 [
   Time,
   {:%{}, [line: 941],
    [
      calendar: Calendar.ISO,
      hour: 14,
      minute: 30,
      second: 0,
      microsecond: {0, 0}
    ]}
 ]}
```

---

<a id="n-naive-datetime"></a>

### ~N (naive datetime)

Naive datetime sigil

**Code:**
```elixir
~N[2024-01-15 14:30:00]
```

**Expanded AST:**
```elixir
{:%, [line: 946],
 [
   NaiveDateTime,
   {:%{}, [line: 946],
    [
      calendar: Calendar.ISO,
      year: 2024,
      month: 1,
      day: 15,
      hour: 14,
      minute: 30,
      second: 0,
      microsecond: {0, 0}
    ]}
 ]}
```

---

<a id="u-utc-datetime"></a>

### ~U (UTC datetime)

UTC datetime sigil

**Code:**
```elixir
~U[2024-01-15 14:30:00Z]
```

**Expanded AST:**
```elixir
{:%, [line: 950],
 [
   DateTime,
   {:%{}, [line: 950],
    [
      calendar: Calendar.ISO,
      year: 2024,
      month: 1,
      day: 15,
      hour: 14,
      minute: 30,
      second: 0,
      microsecond: {0, 0},
      time_zone: "Etc/UTC",
      zone_abbr: "UTC",
      utc_offset: 0,
      std_offset: 0
    ]}
 ]}
```

## Access and Updates

<a id="bracket-access"></a>

### Bracket access

Access by key

**Code:**
```elixir
data[:key]
```

**Expanded AST:**
```elixir
{{:., [from_brackets: true, line: 956, column: 9], [Access, :get]},
 [from_brackets: true, line: 956, column: 9],
 [{:data, [version: 0, line: 956, column: 5], nil}, :key]}
```

---

<a id="get_in"></a>

### get_in

Nested get

**Code:**
```elixir
get_in(data, [:a, :b])
```

**Expanded AST:**
```elixir
{{:., [line: 962, column: 5], [Kernel, :get_in]}, [line: 962, column: 5],
 [{:data, [version: 0, line: 962, column: 12], nil}, [:a, :b]]}
```

---

<a id="put_in"></a>

### put_in

Nested put

**Code:**
```elixir
put_in(data, [:a, :b], value)
```

**Expanded AST:**
```elixir
{{:., [line: 968, column: 5], [Kernel, :put_in]}, [line: 968, column: 5],
 [
   {:data, [version: 0, line: 968, column: 12], nil},
   [:a, :b],
   {:value, [version: 1, line: 968, column: 28], nil}
 ]}
```

---

<a id="update_in"></a>

### update_in

Nested update

**Code:**
```elixir
update_in(data, [:a, :b], &(&1 + 1))
```

**Expanded AST:**
```elixir
{{:., [line: 974, column: 5], [Kernel, :update_in]}, [line: 974, column: 5],
 [
   {:data, [version: 0, line: 974, column: 15], nil},
   [:a, :b],
   {:fn, [capture: true, line: 974, column: 36],
    [
      {:->, [line: 974, column: 36],
       [
         [
           {:capture,
            [
              version: 1,
              counter: {Dx.Dev.ElixirSyntaxReference, 591},
              capture: 1,
              line: 974,
              column: 33
            ], nil}
         ],
         {{:., [line: 974, column: 36], [:erlang, :+]}, [line: 974, column: 36],
          [
            {:capture,
             [
               version: 1,
               counter: {Dx.Dev.ElixirSyntaxReference, 591},
               capture: 1,
               line: 974,
               column: 33
             ], nil},
            1
          ]}
       ]}
    ]}
 ]}
```

---

<a id="get_and_update_in"></a>

### get_and_update_in

Nested get and update

**Code:**
```elixir
get_and_update_in(data, [:a], &{&1, &1 + 1})
```

**Expanded AST:**
```elixir
{{:., [line: 980, column: 5], [Kernel, :get_and_update_in]},
 [line: 980, column: 5],
 [
   {:data, [version: 0, line: 980, column: 23], nil},
   [:a],
   {:fn, [capture: true, line: 980, column: 35],
    [
      {:->, [line: 980, column: 35],
       [
         [
           {:capture,
            [
              version: 1,
              counter: {Dx.Dev.ElixirSyntaxReference, 592},
              capture: 1,
              line: 980,
              column: 37
            ], nil}
         ],
         {:{}, [line: 980, column: 35],
          [
            {:capture,
             [
               version: 1,
               counter: {Dx.Dev.ElixirSyntaxReference, 592},
               capture: 1,
               line: 980,
               column: 37
             ], nil},
            {{:., [line: 980, column: 44], [:erlang, :+]},
             [line: 980, column: 44],
             [
               {:capture,
                [
                  version: 1,
                  counter: {Dx.Dev.ElixirSyntaxReference, 592},
                  capture: 1,
                  line: 980,
                  column: 37
                ], nil},
               1
             ]}
          ]}
       ]}
    ]}
 ]}
```

---

<a id="pop_in"></a>

### pop_in

Nested pop

**Code:**
```elixir
pop_in(data, [:a, :b])
```

**Expanded AST:**
```elixir
{{:., [line: 986, column: 5], [Kernel, :pop_in]}, [line: 986, column: 5],
 [{:data, [version: 0, line: 986, column: 12], nil}, [:a, :b]]}
```

---

<a id="tap"></a>

### tap

Pipeline side-effect helper

**Code:**
```elixir
value |> tap(&IO.inspect/1) |> process()
```

**Expanded AST:**
```elixir
{:process, [line: 992, column: 36],
 [
   {:__block__, [line: 992],
    [
      {:=, [line: 992],
       [
         {:fun,
          [version: 1, counter: {Dx.Dev.ElixirSyntaxReference, 595}, line: 1404],
          Kernel},
         {:&, [line: 992, column: 18],
          [
            {:/, [],
             [
               {{:., [line: 992, column: 21], [IO, :inspect]},
                [no_parens: true, line: 992, column: 22], []},
               1
             ]}
          ]}
       ]},
      {:=, [line: 992],
       [
         {:value,
          [version: 2, counter: {Dx.Dev.ElixirSyntaxReference, 595}, line: 1404],
          Kernel},
         {:value, [version: 0, line: 992, column: 5], nil}
       ]},
      {:__block__, [line: 992],
       [
         {:=, [line: 992],
          [
            {:_, [line: 992], Kernel},
            {{:., [line: 992],
              [
                {:fun,
                 [
                   version: 1,
                   line: 992,
                   counter: {Dx.Dev.ElixirSyntaxReference, 595}
                 ], Kernel}
              ]}, [line: 992],
             [
               {:value,
                [
                  version: 2,
                  line: 992,
                  counter: {Dx.Dev.ElixirSyntaxReference, 595}
                ], Kernel}
             ]}
          ]},
         {:value,
          [version: 2, line: 992, counter: {Dx.Dev.ElixirSyntaxReference, 595}],
          Kernel}
       ]}
    ]}
 ]}
```

---

<a id="then"></a>

### then

Pipeline transform helper

**Code:**
```elixir
value |> then(&{:ok, &1})
```

**Expanded AST:**
```elixir
{{:., [line: 998],
  [
    {:fn, [capture: true, line: 998, column: 19],
     [
       {:->, [line: 998, column: 19],
        [
          [
            {:capture,
             [
               version: 1,
               counter: {Dx.Dev.ElixirSyntaxReference, 598},
               capture: 1,
               line: 998,
               column: 26
             ], nil}
          ],
          {:{}, [line: 998, column: 19],
           [
             :ok,
             {:capture,
              [
                version: 1,
                counter: {Dx.Dev.ElixirSyntaxReference, 598},
                capture: 1,
                line: 998,
                column: 26
              ], nil}
           ]}
        ]}
     ]}
  ]}, [line: 998], [{:value, [version: 0, line: 998, column: 5], nil}]}
```

## Module Directives

<a id="import"></a>

### import

Import functions in scope

**Code:**
```elixir
import Enum, only: [map: 2]
map([1, 2], &(&1 * 2))
```

**Expanded AST:**
```elixir
{:__block__, [line: 1005, column: 9],
 [
   Enum,
   {{:., [line: 1007, column: 5], [Enum, :map]}, [line: 1007, column: 5],
    [
      [1, 2],
      {:fn, [capture: true, line: 1007, column: 22],
       [
         {:->, [line: 1007, column: 22],
          [
            [
              {:capture,
               [
                 version: 0,
                 counter: {Dx.Dev.ElixirSyntaxReference, 599},
                 capture: 1,
                 line: 1007,
                 column: 19
               ], nil}
            ],
            {{:., [line: 1007, column: 22], [:erlang, :*]},
             [line: 1007, column: 22],
             [
               {:capture,
                [
                  version: 0,
                  counter: {Dx.Dev.ElixirSyntaxReference, 599},
                  capture: 1,
                  line: 1007,
                  column: 19
                ], nil},
               2
             ]}
          ]}
       ]}
    ]}
 ]}
```

---

<a id="alias"></a>

### alias

Alias module name

**Code:**
```elixir
alias String, as: S
S.upcase("hello")
```

**Expanded AST:**
```elixir
{:__block__, [line: 1014, column: 9],
 [
   String,
   {{:., [line: 1016, column: 6], [String, :upcase]}, [line: 1016, column: 7],
    ["hello"]}
 ]}
```

---

<a id="require"></a>

### require

Require macro module

**Code:**
```elixir
require Integer
Integer.is_even(2)
```

**Expanded AST:**
```elixir
{:__block__, [line: 1023, column: 9],
 [
   Integer,
   {:__block__, [line: 1025, generated: true],
    [
      {:=, [line: 1025, generated: true],
       [
         {:{}, [line: 1025, generated: true],
          [
            {:arg1,
             [version: 0, line: 1025, generated: true, counter: {Integer, 86}],
             Integer}
          ]},
         {:{}, [line: 1025, generated: true], [2]}
       ]},
      {{:., [line: 1025, generated: true], [:erlang, :andalso]},
       [line: 1025, generated: true],
       [
         {{:., [line: 1025, generated: true], [:erlang, :is_integer]},
          [line: 1025, generated: true],
          [
            {:arg1,
             [version: 0, line: 1025, generated: true, counter: {Integer, 86}],
             Integer}
          ]},
         {{:., [line: 1025, generated: true], [:erlang, :==]},
          [line: 1025, generated: true],
          [
            {{:., [line: 1025, generated: true], [:erlang, :band]},
             [line: 1025, generated: true],
             [
               {:arg1,
                [
                  version: 0,
                  line: 1025,
                  generated: true,
                  counter: {Integer, 86}
                ], Integer},
               1
             ]},
            0
          ]}
       ]}
    ]}
 ]}
```

---

<a id="module-attribute"></a>

### Module attribute

Read module attribute

**Code:**
```elixir
@my_attribute
```

**Expanded AST:**
```elixir
:sample_attribute
```

---

<a id="block-keyword"></a>

### Block (keyword)

Keyword block syntax

**Code:**
```elixir
if(true, do: :ok, else: :error)
```

**Expanded AST:**
```elixir
{:case, [line: 1035, optimize_boolean: true, type_check: {:case, :if}],
 [
   true,
   [
     do: [
       {:->, [line: 1035], [[false], :error]},
       {:->, [line: 1035], [[true], :ok]}
     ]
   ]
 ]}
```

