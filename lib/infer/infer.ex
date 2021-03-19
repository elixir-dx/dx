defmodule Infer do
  @moduledoc """
  `use Infer.Ecto.Schema` enables a module to specify inferences, such as

  ```elixir
  use Infer.Ecto.Schema

  infer :has_children?, when: %{relatives: %{relation: "parent_of"}}
  ```

  Unlike full-fledged inference engines (such as [calypte](https://github.com/liveforeverx/calypte) or [retex](https://github.com/lorenzosinisi/retex)),
  all rules in Infer are bound to an individual record type as their subject. This, in turn, allows to utilize Ecto schemas and queries to their full extent.

  ## Terminology

  - `infer ...` defines a **rule** in a module. It applies to an instance of that module: A struct, Ecto record, Ash resource, ...
  - The first argument, or `:then` part, e.g. `infer :has_children?` is the **result**, or **assigns**, of the rule (inspired by `assigns` in `Plug`).
  - The result assigns a value to each **predicate**, e.g. the value `true` to the predicate `:has_children?`.
  - It helps to differentiate **pure predicates** that are not stored anywhere, from **fields** that are stored and can also be predicates.
  - The `:when` part of a rule defines the **condition**.
  - The current instance is the **subject**.
  - An executed rule results in a (derived) **fact**: subject, predicate, value.

  ## Assigns

  - Rules further up have precedence over those further down. In other words, rules are executed from top to bottom,
    but predicates are not overwritten within one execution run.
  - Assigns are deep-merged, e.g. when assigning `%{name: %{editable: false}}` onto an existing `%{name: %{value: "Su"}}`,
    the result will be `%{name: %{value: "Su", editable: false}}`.
  - Assigning a list to an existing list will append the assigned list to the existing one.
  - Instead of a simple key, a list of keys can be given as a key as a short hand to setting the same value for
    all listed keys, e.g. `%{[:admin?, :senior?] => true}`. This also enables using predicate groups as keys.

  ## Conditions

  - Maps represent multiple conditions, of which all need to be satisfied (logical `AND`)
  - Lists represent multiple conditions, of which at least one needs to be satisfied (logical `OR`)
  - A single atom is a shorthand for `%{atom: true}`
  - Values can be negated using `{:not, "value"}`. For now, this only works for simple (non-nested) values.

  ### Conditions on list values

  When conditions are tested against list values, e.g. a person's list of roles, the condition is satisfied
  if at least one element of the list matches the given conditions (like `Enum.any?/2`).

  Although they might look similar, it's important to differentiate between lists that appear in
  conditions, and lists that appear in the data, which are checked against a condition.

  When both occur together, i.e. a list in a condition is checked against a list of values, the condition
  is met if at least one of the condition list elements applies to at least one element of the value list.

  For example:

  ```elixir
  infer :can_edit?, when: %{roles: ["project_manager", "admin"]}

  iex> %Person{roles: ["worker", "assistant"]} |> Infer.get(:can_edit?)
  nil

  iex> %Person{roles: ["assistant", "project_manager"]} |> Infer.get(:can_edit?)
  true

  iex> %Person{roles: ["admin"]} |> Infer.get(:can_edit?)
  true
  ```

  The same applies to complex conditions.

  #### Conditions on all list values (experimental)

  To specify that it has to apply to all elements in a list, use `{:all?, condition}` (like `Enum.all?/2`).

  For example:

  ```elixir
  infer :can_edit?, when: %{roles: {:all?, ["project_manager", "admin"]}}

  iex> %Person{roles: ["worker", "assistant"]} |> Infer.get(:can_edit?)
  nil

  iex> %Person{roles: ["assistant", "project_manager"]} |> Infer.get(:can_edit?)
  nil

  iex> %Person{roles: ["admin"]} |> Infer.get(:can_edit?)
  true
  ```

  When condition B must be satisfied by all list elements that satisfy condition A,
  `:all?` can be used as a key in the condition map.

  ```elixir
  infer :all_children_adults?,
    when: %{
      relatives: %{
        relation: "parent_of",
        all?: %{other_person: :adult?}
      }
    }

  iex> %Person{
  ...>   relatives: [
  ...>     %Relation{relation: "sibling", other_person: %Person{adult?: true}},
  ...>     %Relation{relation: "parent_of", other_person: %Person{adult?: true}}
  ...>   ]
  ...> }
  ...> |> Infer.get(:all_children_adults?)
  true

  iex> %Person{
  ...>   relatives: [
  ...>     %Relation{relation: "sibling", other_person: %Person{adult?: true}},
  ...>     %Relation{relation: "parent_of", other_person: %Person{adult?: true}},
  ...>     %Relation{relation: "parent_of", other_person: %Person{adult?: false}},
  ...>   ]
  ...> }
  ...> |> Infer.get(:all_children_adults?)
  nil

  # no match when there is no element with `relation: "parent_of"`
  iex> %Person{
  ...>   relatives: [
  ...>     %Relation{relation: "sibling", other_person: %Person{adult?: true}}
  ...>   ]
  ...> }
  ...> |> Infer.get(:all_children_adults?)
  nil
  ```

  ## Predicates

  All keys defined in the following places can be used. They share the same namespace, so each key needs
  to be unique across all these.

  - Fields defined in an ecto schema (see [below](#module-ecto-schema-fields))
  - Attributes defined in `infer` statements
  - Groups defined in `predicate_group` statements
  - `:args` for accessing arguments passed to executing functions, e.g. `args: %{user: nil}` from `Infer.get(Offer, :film?, args: [user: user])`

  ### Preloading

  By default, Infer will not load any fields from the database that are not required, except for primary keys.

  Preloading means to explicitly load all data (nested fields) that required to infer a given list of predicates:

  ```elixir
  infer :has_children?, when: %{relatives: %{relation: "parent_of"}}

  # Loads all relatives including their `relation` field, if not loaded yet:
  Infer.preload(%Person{}, [:has_children?])

  # Querying does not load the data when the conditions can be checked by the database.
  # When needed, they can be preloaded in addition:
  Infer.query(Person, :has_children?, preload: [:has_children?])
  ```

  ### Predicate groups

  Groups with multiple predicates can be defined and used as shorthands in assigns and preloads.
  See `predicate_group/1` for examples.

  By default, Infer defines `:all_fields` as a group of all fields defined, e.g. Struct fields, Ecto schema fields, ...

  ### Predicates with meta data

  When using Infer, a list of predicates can be defined to have meta data.
  This means, not only the value of the predicate can be set, but the predicate internally becomes
  a map with a `:value` key for the actual value, and any other keys to be set as meta data.

  By default, `:all_fields` have meta data.

  This can be useful for generating forms and other scenarios, for example:

  ```elixir
  name: %{
    value: "Su",
    required: false,
    editable: true,
    visible: true
  }
  ```

  **Note:** Meta data can **not** be used in **conditions**. It can only be assigned and used in other places.
  Conditions will always access the `:value` directly, just as if the predicate had no meta data.

  Example combining predicate meta data, predicate groups, and preloading:

  ```elixir
  predicate_group form_fields: [:name, :roles]

  infer form_fields: %{ediable: true}, when: %{args: %{user: %{roles: "admin"}}}

  iex> Infer.query(Person, :has_children?, args: [user: user], preload: [:form_fields])
  {:ok, [%Person{}, ...], [%{has_children?: true, name: %{editable: true}, roles: %{editable: true}}]}
  ```

  ### Predicate cache

  You can define a `field :inferred, :map, virtual: true` on your Ecto schema.
  If you do, `Infer` will use it to store a copy of results inferred by executing
  functions (such as `Infer.get/3`) in a map in this field, like a cache.

  ### Referencing values in condition (experimental)

  `{:ref, [...]}` is a reference to a **path**, starting from the subject.

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

  ### Binding values in condition (highly experimental)

  When a condition is evaluated on a list of values, the **first value** satisfying
  the condition can be bound to a variable using `{:bind, variable}`.

  `{:bind, variable}` creates a temporary predicate on the root (subject) level,
  which can be referenced using `{:ref, [...]}`.

  A path consisting of one element can have its brackets omitted.

  ```elixir
  infer project_manager: {:ref, :person},
      when: %{roles: %{type: "project_manager", person: {:bind, :person}}}
  ```

  `{:bind_all, variable}` works in the same way, but binds a list of all matching
  list values to the variable.

  It can be used via `{:ref, variable}`, or also `{:count, variable}` which returns
  the number of elements in the bound list.

  ```elixir
  infer project_managers: {:count, :person},
      when: %{roles: %{type: "project_manager", person: {:bind_all, :person}}}
  ```

  ## Rule checks at compile-time

  Problems that can be detected at compile-time:

  - Invalid rule: "Rule X uses non-existing predicate `:has_child?`. Did you mean `:has_children?`"
  - Invalid function call: "`Infer.get(%Person{}, :has_child?)` uses non-existing predicate `:has_child?`. Did you mean `:has_children?`"
  - Cycles in rule definitions: "Cycle detected: Rule X on Person references Rule Y on Role. Rule Y on Role references Rule X on Person."
  - Unreachable rules: "Rule Y can never be reached, as Rule X always matches."

  """

  @doc """
  Evaluates one or multiple predicates for one or multiple records and returns the results.

  ## Options

  - `:with_meta` (boolean) - whether or not to return a map for predicates with meta data.
    When `false`, only the values are returned for all predicates. Default: `true`.
  """
  def get(records, predicates, opts \\ [])

  def get(records, predicates, opts) when is_list(records) do
    records
    |> preload(predicates, opts)
    |> Enum.map(&get(&1, predicates, opts))
  end

  def get(record, predicates, opts) when is_list(predicates) do
    record = preload(record, predicates, opts)
    Map.new(predicates, &{&1, get(record, &1, opts)})
  end

  def get(record, predicate, opts) when is_atom(predicate) do
    if opts[:preload] == true do
      try do
        Infer.Engine.resolve_predicate(predicate, record, opts)
      rescue
        Infer.Error.NotLoaded ->
          record = preload(record, predicate, opts)
          Infer.Engine.resolve_predicate(predicate, record, opts)
      end
    else
      Infer.Engine.resolve_predicate(predicate, record, opts)
    end
  end

  @doc """
  Evaluates the given predicate(s) for the given record(s) and merges the
  results into the [predicate cache](#module-predicate-cache) of the record(s).

  ## Options

  Same as for `get/3`.
  """
  def put(records, predicates, opts \\ [])

  def put(records, predicates, opts) when is_list(records) do
    Enum.map(records, &put(&1, predicates, opts))
  end

  def put(record, predicates, opts) do
    %{record | inferred: get(record, predicates, opts)}
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

  def preload(records = [%type{} | _], preloads, opts) do
    do_preload(records, type, preloads, opts)
  end

  def preload(record = %type{}, preloads, opts) do
    do_preload(record, type, preloads, opts)
  end

  defp do_preload(record_or_records, type, preloads, opts) do
    preloads = Infer.Preloader.preload_for_predicates(type, List.wrap(preloads), opts)

    type.infer_preload(record_or_records, preloads, opts)
  end

  @doc "Removes all elements not matching the given condition from the given list."
  def filter(records, condition, opts \\ []) when is_list(records) do
    Enum.filter(records, &get(&1, condition, opts))
  end

  @doc "Removes all elements matching the given condition from the given list."
  def reject(records, condition, opts \\ []) when is_list(records) do
    Enum.reject(records, &get(&1, condition, opts))
  end

  @doc """
  Returns all records matching the given condition.

  ## Options

  - `:base_query` (Ecto.Query) - query to use as a base for retrieving records.
    Can be used for additional conditions, pagination, etc. Default: `Ecto.Query.from(x in ^type)`.
  - `:put` (predicate list) - predicates to evaluate, which are not part of the condition (requires [predicate cache](#module-predicate-cache)).
  - `:put_with_meta` (boolean) - whether or not the predicates listed in `:put` return a map when they have meta data.
    When `false`, only the value is returned for each. Default: `true`.
  - `:preload` (predicate list) - load all data required to evaluate the given predicate(s) on the results (also see `preload/2`).

  ### Using `:put` and `:preload`

  In general, as much work as possible is done in the database:

  - If possible, the condition is completely translated to an `Ecto.Query` so the database only returns matching records.
  - Even predicates given via `:put` are evaluated in the database and returned as a single value, whenever possible.
  - Use `:preload` to ensure that data is loaded, which is required to evaluate the given predicate(s) in the application.

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
  def query_all(_type, _condition, _opts \\ []) do
    # ...
  end

  @doc """
  Returns the first record matching the given condition.

  ## Options

  Same as for `query_all/3`.
  """
  def query_one(_type, _condition, _opts \\ []) do
    # ...
  end
end
