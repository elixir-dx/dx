# Infer

Infer is an inference engine that allows to declare logic based on data schemas (such as Ecto)
in a central and concise way.

## Why Infer?

Infer offers a declarative approach to application logic that especially shines in apps with:

- Complex data schemas, especially when rules need to look at data in many multiple or deeply
  nested associated types/modules
- Complex application logic, especially with many "edge cases" and other conditional logic
- Large parts of the data being loaded (e.g. from the database) is only needed to compute final
  results

Infer helps in these cases, because:

- Application logic is declared in a concise and clean way that's readable even to
  non-developers (with a short introduction)
- Application logic can be laid out into modules as it makes sense for the application domain, not the code
- No execution code needs to be written, just call `Infer` with a single or list of records and
  the desired results, and it will compute them
- Infer loads required data as needed (e.g. from the database), in an optimized way that applies
  filtering, batching and concurrency, and avoids overfetching

## Status

Infer is sponsored by Team Engine, where we've been developing it internally since January 2021.
We've been using it in production since March 2021, and increasingly port our business logic to it.
To make it an easy-to-adopt open-source library, the next steps are to:

- [x] extract the code into this repo
- [ ] re-add tests (because they were domain-specific)
- [ ] write guides, a reference and an announcement
- [ ] resolve absinthe-graphql/dataloader#129 and re-add dataloader as a hex dependency
- [ ] release on hex.pm

## Installation

Add `infer` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:infer, github: "infer-beam/infer"}
  ]
end
```

Configure your repo in `config.exs`:

```elixir
config :infer, repo: MyApp.Repo
```

Import the formatter rules in `.formatter.exs`:

```elixir
[
  import_deps: [:infer]
]
```

# Usage

`use Infer.Ecto.Schema` enables a module to specify inferences, such as

```elixir
use Infer.Ecto.Schema

infer has_children?: true, when: %{relatives: %{relation: "parent_of"}}
infer has_children?: false
```

Unlike full-fledged inference engines (such as [calypte](https://github.com/liveforeverx/calypte)
or [retex](https://github.com/lorenzosinisi/retex)), all rules in Infer are bound to an individual
record type as their subject. This, in turn, allows to utilize Ecto schemas and queries to their full extent.

## Terminology

- `infer ...` defines a **rule** in a module. It applies to an instance of that module:
  A struct, Ecto record, Ash resource, ...
- This instance of a module, on which rules are evaluated, is the **subject**.
- A rule can have a **condition**, or `:when` part, that must be met in order for it to apply,
  e.g. `%{relatives: %{relation: "parent_of"}}`.
- When the condition is met, a given **predicate** is assigned a given **value**,
  e.g. `has_children?: true`. This is also called the **result** of the rule.
- All rules are evaluated from top to bottom until the first one for each predicate matches,
  similar to a `cond` statement.
- A condition can make use of other predicates as well as **fields** defined on the schema or
  struct of the underlying type.
- An executed rule results in a (derived) **fact**: subject, predicate, value.

## API overview

- `Infer.get/3` evaluates the given predicate(s) using only the (pre)loaded data available, and returns the result(s)
- `Infer.load/3` is like `get`, but loads any additional data as needed
- `Infer.put/3` is like `load`, but puts the results into the `:inferred` field
  (or virtual schema field) of the subject(s) as a map, and returns the subject(s)

These functions return a tuple, either `{:ok, result}`, `{:error, error}`, or `{:not_loaded, data_reqs}` (only `get`).

The corresponding `Infer.get!/3`, `Infer.load!/3` and `Infer.put!/3` functions return `result`
directly, or otherwise raise an exception.

Arguments:

- **subjects** can either be an individual subject (with the given predicates defined on it), or a list of subjects.
  Passing an individual subject will return the predicates for the subject, passing a list will return a list of them.
- **predicates** can either be a single predicate, or a list of predicates.
  Passing a single predicate will return the resulting value, passing a list will return a **map**
  of the predicates and their resulting values.
- **options** (optional) See below.

Options:

- **args** (list or map) can be used to pass in data from the caller's context that can be used in
  rules (see _Arguments_ below). A classic example is the `current_user`, e.g.
  ```elixir
  Infer.put!(project, :can_edit?, args: [user: current_user])
  ```
- **extra_rules** (module or list of modules) can be used to add context-specific rules that are
  not defined directly on the subject. This can be used to structure rules into their own modules
  and use them only where needed.
- **debug?** (boolean) makes Infer print additional information to the console as rules are evaluated.
  Should only be used while debugging.

## Conditions

In a rule condition, the part after `when: ...`,

- **Maps** represent multiple conditions, of which **all** need to be satisfied (logical `AND`).
- **Lists** represent multiple conditions, of which **at least one** needs to be satisfied (logical `OR`).
- Values can be negated using `{:not, "value"}`.

Examples:

```elixir
# :role must be "admin"
infer role: :admin, when: %{role: "admin"}

# :role must be either "admin" or "superadmin"
infer role: :admin, when: %{role: ["admin", "superadmin"]}

# :role must be "admin" and :verified? must be true
infer role: :admin, when: %{role: "admin", verified?: true}

# :role must be "admin" and :verified_at must not be nil
infer role: :admin, when: %{role: "admin", verified_at: {:not, nil}}
```

### Boolean shorthand form

A single atom is a shorthand for `%{atom: true}`.

### Conditions on list data

When conditions are tested against list data, e.g. a person's list of roles, the condition is satisfied
if at least one element of the list matches the given conditions (like `Enum.any?/2`).

Although they might look similar, it's important to differentiate between lists that appear in
conditions, and lists that appear in the data, which are checked against a condition.

When both occur together, i.e. a list in a condition is checked against a list of values, the condition
is met if at least one of the condition list elements applies to at least one element of the value list.

For example:

```elixir
infer :can_edit?, when: %{roles: ["project_manager", "admin"]}

iex> %Person{roles: ["worker", "assistant"]} |> Infer.get!(:can_edit?)
nil

iex> %Person{roles: ["assistant", "project_manager"]} |> Infer.get!(:can_edit?)
true

iex> %Person{roles: ["admin"]} |> Infer.get!(:can_edit?)
true
```

The same applies to complex conditions.

## Rule results

The assigned value of a predicate is generally assigned as is.

A few special tuples, however, will be replaced by Infer (see _Features_ below)

Example:

```elixir
infer d: 4
infer nested: %{a: 1, b: 2, c: {:ref, :d}}  # => %{a: 1, b: 2, c: 4}
```

## Features

### References

Syntax:

- `{:ref, path}` (in conditions and result values)

Arguments:

- **path** is a list of fields or predicates, starting from the subject.
  The brackets can be omitted (i.a. an atom passed), if the path consists of one element.
  The last element can be a map or list (see _Branching_ below)

Example:

```elixir
infer ot_fields: %{editable: true},
    when: %{
      construction_bectu?: true,
      roles: %{
        user: {:ref, [:args, :user]},
        type: ["project_manager", "admin"]
      }
    }
```

#### Branching

Any part of the `path` that represents an underlying **list of subjects**, such as referencing
a `has_many` association, will cause the result of the `:ref` to be a list as well.
It basically behaves similar to `Enum.map/2`.

A **map** as last element of a `path` will branch the returned result out into this map.
The keys are returned as is, the values must be a list (or atom) continuing that path.
This is particularly powerful when used on a list of subjects (see above), because it
will return the given map with the values at the given paths for each underlying subject:

A **list** as last element of a `path` behaves like a map where each value equals its key.

Examples:

```elixir
infer list: [%{a: 1, b: 2, c: %{d: 4}}, %{a: 9, b: 8, c: %{d: 6}}]

infer result1: {:ref, [:list, :a]}  # => [1, 9]
infer result2: {:ref, [:list, %{x: :a, y: [:c, :d]}]}  # => [%{x: 1, y: 4}, %{x: 9, y: 6}]
infer result3: {:ref, [:list, [:a, :b]]}  # => [%{a: 1, b: 2}, %{a: 9, b: 8}]
```

### Arguments

Passing `:args` as an option to any of the Infer API functions enables referencing the passed data
in conditions and values using `{:ref, [:args, ...]}`.

### Overriding existing fields

It's possible to give predicates the same name as existing fields in the schema.
This represents the fact that these fields are derived from other data, using rules.

Rules on these fields can even take into account the existing value of the underlying field.
In order to reference it, use `:fields` in between a path or condition, for example:

```elixir
schema "blog_posts" do
  field :state
  field :published_at
end

# nilify published_at when deleted, or when it's an old archived post
infer published_at: nil, when: %{state: "deleted"}
infer published_at: nil, when: %{state: "archived", fields: %{published_at: {:before, ~D[2020-02-20]}}}
infer published_at: {:ref, [:fields, :published_at]}
```

While it's always possible to achieve a similar behavior by giving the predicate a different
name than the field, and then mapping the predicate to the field somewhere else,
using the field name in conjunction with `:fields` makes explicit that it's a conditional override.

### Binding subject parts

Syntax:

- `{:bind, key}` (in conditions)
- `{:bind, key, subcondition}` (in conditions)
- `{:bound, key}` (in result values)
- `{:bound, key, default}` (in result values)

When a condition is evaluated on a list of values, the **first value** satisfying
the condition can be bound to a variable using `{:bind, variable}`.

These bound values can be referenced using `{:bound, key}` with an optional default:
`{:bound, key, default}`.

```elixir
infer project_manager: {:bound, :person},
    when: %{roles: %{type: "project_manager", person: {:bind, :person}}}
```

### Local aliases

Syntax:

- `infer_alias key: ...` (in modules before using `key` in `infer ...`)

In order to create shorthands and avoid repetition, aliases can be defined.
These apply only to subsequent rules within the same module and are not exposed in any other way.

```elixir
infer_alias pm?: %{roles: %{type: ["project_manager", admin]}}

infer ot_fields: %{editable: true}, when: [:pm?, %{construction_bectu?: true}]
```

### Calling functions

Syntax:

- `{&module.fun/n, [arg_1, ..., arg_n]}` (in result values)
- `{&module.fun/1, arg_1}` (in result values)

Any function can be called to map the given arguments to other values.
The function arguments must be passed as a list, except if it's only one.
Arguments can be fixed values or other Infer features (passed as is), such as references.

```elixir
infer day_of_week: {&Date.day_of_week/1, {:ref, :date}}

infer duration: {&Timex.diff/3, [{:ref, :start_datetime}, {:ref, :end_datetime}, :hours]}
```

Only pure functions with low overhead should be used.
Infer might call them very often during evaluation (once after each loading of data).

### Querying

Syntax:

- `{:query_one, type, conditions}`
- `{:query_one, type, conditions, options}`
- `{:query_first, type, conditions}`
- `{:query_first, type, conditions, options}`
- `{:query_all, type, conditions}`
- `{:query_all, type, conditions, options}`

Arguments:

- `type` is a module name (or Ecto queryable), e.g. an Ecto schema
- `conditions` is a **keyword list** of fields and their respective values, or lists of values, they must match
- `options` is a subset of the options that Ecto queries support:
  - `order_by`
  - `limit`

#### Conditions

The first key-value pair has a special behavior:
It is used as the main condition for `Dataloader`, and thus should have the highest cardinality.
It must be a single value, not a list of values.

_Rule of thumb:_ Put a single field that has the most unique values as first condition.

### Transforming lists

Syntax:

- `{:filter, source, condition}` (in result values)
- `{:map, source, mapper}` (in result values)
- `{:map, source, bind_key/condition, mapper}` (in result values)

Arguments:

- `source` can either be a list literal, a field or predicate that evaluates to a list,
  or another feature such as a query.
- `condition` has the same form and functionality as any other rule condition.
- `mapper` can either be a field or predicate (atom), or is otherwise treated as any other rule value.

There are 3 variants:

- `{:filter, source, condition}` keeps only elements from `source`, for which the `condition` is met.
- `{:map, source, mapper}` returns the result of `mapper` for each element in `source`.
- `{:map, source, bind_key/condition, mapper}` is a special form of `:map`, where the `mapper` is based on the
  subject of the rule, not the list element. The list element is referenced using the middle arg, which can be either:
  - a `bind_key` (atom) - the current list element is referenced via `{:bound, bind_key}` in the `mapper`
  - a `condition` - any values bound in the condition via `{:bind, key, ...}` can be accessed
    via `{:bound, key}` in the `mapper`

Use the special form of `:map` only when you need to reference both the list element (via `:bound`),
and the subject of the rule (via `:ref`).
Using a combination of `:filter` and basic `:map` instead is always preferred, if possible.

Any `nil` elements in the list are mapped to `nil`, when using `:map` without condition.

Examples:

```elixir
infer accepted_offers: {:filter, :offers, %{state: "accepted"}}

infer offer_ids: {:map, :offers, :id}

infer first_offer_of_same_user:
        {:map, :offers, %{state: "accepted", user_id: {:bind, :uid, {:not, nil}}},
         {:query_first, Offer, user_id: {:bound, :uid}, project_id: {:ref, :project_id}}}
```

### Counting

Syntax:

- `{:count, source, condition/predicate}` (in result values)
- `{:count_while, source, condition/predicate}` (in result values)

Arguments:

- `source` can either be a list literal, a field or predicate that evaluates to a list,
  or another feature such as a query.
- `condition` has the same form and functionality as any other rule condition.
- `predicate` can either be a predicate (atom) that returns either `true`, `false`,
  or `:skip` (only for `:count_while`)

Takes the given list and counts the elements that evaluate to `true`.
`:count_while` stops after the first element that returns `false`.
To not count an element, but not stop counting either, the given predicate may return `:skip`.
Any `nil` elements in the list are treated as `false`.

### Predicate groups (not implemented yet)

Groups with multiple predicates can be defined and used as shorthands in assigns and preloads.
See `predicate_group/1` for examples.

By default, Infer defines `:all_fields` as a group of all fields defined, e.g. Struct fields, Ecto schema fields, ...

Uses:

- In API: A group name can be passed to the Infer API to infer all predicates in that group.
- In rule results: Instead of a simple key, a list of keys can be given as a key as a short hand
  to setting the same value for all listed keys, e.g. `%{[:admin?, :senior?] => true}`.
  This also enables using predicate groups as keys.

## Rule checks at compile-time (not implemented yet)

Problems that can be detected at compile-time:

- Invalid rule: "Rule X uses non-existing predicate `:has_child?`. Did you mean `:has_children?`"
- Invalid function call: "`Infer.get!(%Person{}, :has_child?)` uses non-existing
  predicate `:has_child?`. Did you mean `:has_children?`"
- Cycles in rule definitions: "Cycle detected: Rule X on Person references Rule Y on Role.
  Rule Y on Role references Rule X on Person."
- Unreachable rules: "Rule Y can never be reached, as Rule X always matches."
