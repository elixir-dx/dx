defmodule Infer do
  @moduledoc """
  Infer is an inference engine that allows to declare logic based on data schemas (such as Ecto)
  in a central and concise way.

  # Why Infer?

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
    rules (see *Arguments* below). A classic example is the `current_user`, e.g.
    ```elixir
    Infer.put!(project, :can_edit?, args: [user: current_user])
    ```
  - **extra_rules** (module or list of modules) can be used to add context-specific rules that are
    not defined directly on the subject. This can be used to structure rules into their own modules
    and use them only where needed.
  - **debug** (boolean) makes Infer print additional information to the console as rules are evaluated.
    Should only be used while debugging.
  - **return_cache** (boolean) makes non-bang functions return `{:ok, result, cache}` instead of
    `{:ok, result}` on success. This `cache` can be passed to other Infer functions (see `cache` option)
  - **cache** (`Dataloader` struct) can be used to pass in an existing cache, so data already loaded
    doesn't need to be loaded again. Can be initialized using `Infer.Loaders.Dataloader.init/0`.

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

  A few special tuples, however, will be replaced by Infer (see *Features* below)

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
  -  **path** is a list of fields or predicates, starting from the subject.
     The brackets can be omitted (i.a. an atom passed), if the path consists of one element.
     The last element can be a map or list (see *Branching* below)

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

  *Rule of thumb:* Put a single field that has the most unique values as first condition.

  ### Transforming lists

  Syntax:
  - `{:filter, source, condition}` (in result values)
  - `{:map, source, mapper}`  (in result values)
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

  """

  alias Infer.{Engine, Result, Util}
  alias Infer.Evaluation, as: Eval

  @doc """
  Evaluates one or multiple predicates for one or multiple records and returns the results.

  Does not load any additional data.

  ## Options

  - `:with_meta` (boolean) - whether or not to return a map for predicates with meta data.
    When `false`, only the values are returned for all predicates. Default: `true`.
  """
  def get(records, predicates, opts \\ []) do
    eval = Eval.from_options(opts)

    do_get(records, predicates, eval)
    |> Result.to_simple_if(not eval.return_cache?)
  end

  defp do_get(records, predicates, eval) when is_list(records) do
    Result.map(records, &do_get(&1, predicates, eval))
  end

  defp do_get(record, predicates, eval) when is_list(predicates) do
    Result.map(predicates, &Engine.resolve_predicate(&1, record, eval))
    |> Result.transform(&Util.Map.zip(predicates, &1))
  end

  defp do_get(record, predicate, eval) when is_atom(predicate) do
    Engine.resolve_predicate(predicate, record, eval)
  end

  defp do_get(record, result, eval) do
    Engine.map_result(result, %{eval | root_subject: record})
  end

  @doc """
  Like `get/3` but returns the result value, or raises an error.
  """
  def get!(records, predicates, opts \\ []) do
    get(records, predicates, opts)
    |> Result.unwrap!()
  end

  @doc """
  Like `get/3`, but loads additional data if needed.
  """
  def load(records, predicates, opts \\ []) do
    eval = Eval.from_options(opts)

    do_load(records, predicates, eval)
    |> Result.to_simple_if(not eval.return_cache?)
  end

  defp do_load(records, predicates, eval) do
    load_all_data_reqs(eval, fn eval ->
      do_get(records, predicates, eval)
    end)
  end

  defp load_all_data_reqs(eval, fun) do
    case fun.(eval) do
      {:not_loaded, data_reqs} -> Eval.load_data_reqs(eval, data_reqs) |> load_all_data_reqs(fun)
      {:ok, result, _binds} -> {:ok, result, eval.cache}
      other -> other
    end
  end

  @doc """
  Like `get!/3`, but loads additional data if needed.
  """
  def load!(records, predicates, opts \\ []) do
    load(records, predicates, opts)
    |> Result.unwrap!()
  end

  @doc """
  Loads the given predicate(s) for the given record(s) and merges the
  results into the `inferred` map field of the record(s), returning them.

  ## Options

  Same as for `get/3`.
  """
  def put(records, predicates, opts \\ []) do
    eval = Eval.from_options(opts)

    do_load(records, List.wrap(predicates), eval)
    |> Result.transform(&do_put(records, &1))
    |> Result.to_simple_if(not eval.return_cache?)
  end

  defp do_put(records, results) when is_list(records) do
    Util.Enum.zip(records, results, &do_put/2)
  end

  defp do_put(record, results) do
    Map.update!(record, :inferred, &Util.Map.maybe_merge(&1, results))
  end

  def put!(records, predicates, opts \\ []) do
    put(records, predicates, opts)
    |> Result.unwrap!()
  end

  @doc """
  Ensures that the given record(s) have all data loaded that is required to evaluate the given predicate(s).

  ## Options

  - `:refresh` - whether or not to load data again that's already loaded. Default: `false`.

  ## Examples

  Preload data required to infer the value of the predicate `:has_children?`:

  ```
  defmodule Person do
    infer :has_children?, when: %{relatives: %{relation: "parent_of"}}
  end

  iex> Infer.preload(%Person{}, :has_children?)
  %Person{relatives: [%Relation{relation: "sibling"}, ...]}

  iex> Infer.preload([%Person{}, ...], :has_children?)
  [%Person{relatives: [%Relation{relation: "sibling"}, ...]}, ...]
  ```

  """
  def preload(records, preloads, opts \\ [])

  def preload([], _preloads, _opts), do: []

  def preload(record_or_records, preloads, opts) do
    case get(record_or_records, preloads, opts) do
      {:not_loaded, _data_reqs} -> do_preload(record_or_records, preloads, opts)
      _else -> record_or_records
    end
  end

  defp do_preload(record_or_records, preloads, opts) do
    type = get_type(record_or_records)
    preloads = Infer.Preloader.preload_for_predicates(type, List.wrap(preloads), opts)

    type.infer_preload(record_or_records, preloads, opts)
  end

  defp get_type(%Ecto.Query{from: %{source: {_, type}}}), do: type
  defp get_type(%type{}), do: type
  defp get_type([%type{} | _]), do: type

  defp get_type(type) when is_atom(type) do
    Code.ensure_compiled(type)

    if Util.Module.has_function?(type, :infer_rules_for, 2) do
      type
    else
      raise ArgumentError, "Could not derive type from " <> inspect(type, pretty: true)
    end
  end

  @doc """
  Preloads data for a record nested under the given field or path (list of fields)
  inside the given record(s).
  """
  def preload_in(records, field_or_path, preloads, opts \\ [])

  def preload_in(records, field_or_path, preloads, opts) when is_list(records) do
    records
    |> Enum.map(&Util.Map.do_get_in(&1, field_or_path))
    |> preload(preloads, opts)
    |> Util.Enum.zip(records, &Util.Map.do_put_in(&2, field_or_path, &1))
  end

  def preload_in(record, field_or_path, preloads, opts) do
    preloaded_sub_record =
      record
      |> Util.Map.do_get_in(field_or_path)
      |> preload(preloads, opts)

    Util.Map.do_put_in(record, field_or_path, preloaded_sub_record)
  end

  @doc "Removes all elements not matching the given condition from the given list."
  def filter(records, condition, opts \\ []) when is_list(records) do
    eval = Eval.from_options(opts)

    do_filter(records, condition, eval)
  end

  defp do_filter(records, true, _eval) do
    records
  end

  defp do_filter(records, condition, eval) do
    if eval.debug?, do: IO.puts("Infer Filter: #{inspect(condition, pretty: true)}")

    load_all_data_reqs(eval, fn eval ->
      Result.filter_map(
        records,
        &Engine.evaluate_condition(condition, &1, %{eval | root_subject: &1})
      )
    end)
    |> Result.unwrap!()
  end

  @doc "Removes all elements matching the given condition from the given list."
  def reject(records, condition, opts \\ []) when is_list(records) do
    filter(records, {:not, condition}, opts)
  end

  @doc """
  Returns all records matching the given condition.

  ## Options

  - `:base_query` (Ecto.Query) - query to use as a base for retrieving records.
    Can be used for additional conditions, pagination, etc. Default: `Ecto.Query.from(x in ^type)`.
  - `:put` (predicate list) - predicates to evaluate, which are not part of the condition
    (requires [predicate cache](#module-predicate-cache)).
  - `:put_with_meta` (boolean) - whether or not the predicates listed in `:put` return a map when they have meta data.
    When `false`, only the value is returned for each. Default: `true`.
  - `:preload` (predicate list) - load all data required to evaluate the given predicate(s) on the
    results (also see `preload/2`).

  ### Using `:put` and `:preload`

  In general, as much work as possible is done in the database:

  - If possible, the condition is completely translated to an `Ecto.Query` so the database only
    returns matching records.
  - Even predicates given via `:put` are evaluated in the database and returned as a single value, whenever possible.
  - Use `:preload` to ensure that data is loaded, which is required to evaluate the given
    predicate(s) in the application.

  ## Examples

      Entity.query(Offer, :construction_bectu?, preload: [:all_fields])
      # SELECT offers o
      #   INNER JOIN projects p ON p.id = o.project_id
      #   INNER JOIN job_titles j ON j.id = o.job_title_id
      # WHERE
      #   "p.contruction_bectu?" = TRUE AND
      #   j.type <> 'standard'
      {:ok, [%Offer{}, %Offer{}, ...], [%{construction_bectu?: true}, %{construction_bectu?: true}, ...]}

      Entity.query(Offer, %{id: [1, 4, 5], construction_bectu?: true})
      # SELECT offers o
      #   INNER JOIN projects p ON p.id = o.project_id
      #   INNER JOIN job_titles j ON j.id = o.job_title_id
      # WHERE
      #   "p.contruction_bectu?" = TRUE AND
      #   j.type <> 'standard' AND
      #   o.id IN (1, 4, 5)
      {:ok, [%Offer{}, %Offer{}], [%{construction_bectu?: true}, %{construction_bectu?: true}]}

      Entity.query(Offer, %{rate_type: :flat_rate_ot})
      # SELECT offers o
      #   INNER JOIN projects p ON p.id = o.project_id
      # WHERE
      #   (p.type = 'Feature Film' AND
      #    p.bectu_type = 'NONE')
      #   OR
      #   (p.type = 'Television' AND
      #    p.bectu_type IN ('BECTU_CUSTOM_OVERTIME', 'NONE'))
      {:ok, [%Offer{}, %Offer{}, ...], [%{rate_type: :flat_rate_ot}, %{rate_type: :flat_rate_ot}, ...]}
  """
  def query_all(queryable, condition, opts \\ []) do
    {queryable, condition, repo, eval} = build_query(queryable, condition, opts)

    queryable
    |> repo.all()
    |> do_filter(condition, eval)
    |> apply_select(eval)
  end

  @doc """
  Returns the first record matching the given condition.

  ## Options

  Same as for `query_all/3`.
  """
  def query_one(queryable, condition, opts \\ []) do
    {queryable, condition, repo, eval} = build_query(queryable, condition, opts)

    queryable
    |> repo.one!()
    |> do_filter(condition, eval)
    |> apply_select(eval)
  end

  defp build_query(queryable, condition, opts) do
    type = get_type(queryable)
    query_mod = type.infer_query_module()
    repo = type.infer_repo()

    {queryable, opts} = query_mod.apply_options(queryable, opts)

    eval = Eval.from_options(opts)
    {queryable, condition} = query_mod.apply_condition(queryable, condition, eval)

    if eval.debug? do
      sql = query_mod.to_sql(repo, queryable)
      IO.puts("Infer SQL: #{sql}")
    end

    {queryable, condition, repo, eval}
  end

  defp apply_select(records, %{select: nil}), do: records

  defp apply_select(records, %{select: mapping} = eval) do
    load_all_data_reqs(eval, fn eval ->
      Result.map(records, &Engine.map_result(mapping, %{eval | root_subject: &1}))
    end)
    |> Result.unwrap!()
  end
end
