defmodule Infer do
  @moduledoc """
  `use Infer.Ecto.Schema` enables a module to specify inferences, such as

  ```elixir
  use Infer.Ecto.Schema

  infer :has_children?, when: %{relatives: %{relation: "parent_of"}}
  ```

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
  """

  def get(records, infers, opts \\ [])

  def get(records, infers, opts) when is_list(records) do
    Enum.map(records, &get(&1, infers, opts))
  end

  def get(record, infers, opts) when is_list(infers) do
    Map.new(infers, &{&1, get(record, &1, opts)})
  end

  def get(_record, _infer, _opts) do
    # ...
  end

  def preload(records, preloads) when is_list(records) do
    Enum.map(records, &preload(&1, preloads))
  end

  def preload(record, preloads) when is_list(preloads) do
    Enum.reduce(preloads, record, &preload(&2, &1))
  end

  def preload(_record, _preload) do
    # ...
  end

  def fields(_records, _fields_or_groups) do
    # ...
  end

  def filter(records, condition) when is_list(records) do
    Enum.filter(records, &get(&1, condition))
  end

  def reject(records, condition) when is_list(records) do
    Enum.reject(records, &get(&1, condition))
  end

  @doc """
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
      #   (p.type = 'Television Film' AND
      #    p.bectu_type IN ('BECTU_CUSTOM_OVERTIME', 'NONE'))
      {:ok, [%Offer{}, %Offer{}, ...], [%{rate_type: :flat_rate_ot}, %{rate_type: :flat_rate_ot}, ...]}
  """
  def query(_type, _condition, _opts \\ []) do
    # ...
  end
end
