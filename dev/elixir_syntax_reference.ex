defmodule Dx.Dev.ElixirSyntaxReference.User do
  @moduledoc false

  defstruct [:age, :name]
end

defmodule Dx.Dev.ElixirSyntaxReference.Compiler do
  @moduledoc false

  @output_path "docs/elixir_ast_reference.md"

  defmacro __using__(_opts) do
    quote do
      import unquote(__MODULE__), only: [sample: 5]

      Module.register_attribute(__MODULE__, :syntax_samples, accumulate: true)

      @before_compile unquote(__MODULE__)
    end
  end

  defmacro sample(category, title, description, opts, do_block) do
    body = Keyword.fetch!(do_block, :do)
    code = opts |> Keyword.fetch!(:code) |> Macro.expand(__CALLER__)
    args = Keyword.get(opts, :args, [])
    kind = Keyword.get(opts, :kind, :def)
    index = __CALLER__.line
    fun_name = :"__syntax_sample_#{index}__"

    sample = %{
      arity: length(args),
      category: category,
      code: code,
      description: description,
      fun_name: fun_name,
      index: index,
      title: title
    }

    quote do
      @syntax_samples unquote(Macro.escape(sample))
      @doc false
      unquote(kind)(unquote(fun_name)(unquote_splicing(args))) do
        unquote(body)
      end
    end
  end

  defmacro __before_compile__(env) do
    env.module
    |> Module.get_attribute(:syntax_samples, [])
    |> Enum.sort_by(& &1.index)
    |> generate_markdown(env.module)
    |> write_markdown!()

    quote do
      :ok
    end
  end

  defp write_markdown!(markdown) do
    path = Path.expand(@output_path, File.cwd!())

    File.mkdir_p!(Path.dirname(path))
    File.write!(path, markdown)
  end

  defp generate_markdown(samples, module) do
    categories = samples |> Enum.map(& &1.category) |> Enum.uniq()

    [
      "# Elixir AST Reference\n\n",
      "Generated during `MIX_ENV=dev` compilation by `Dx.Dev.ElixirSyntaxReference`.\n\n",
      "Each expanded AST below is read from `Module.get_definition/2` inside an ",
      "`@before_compile` hook, after Elixir has expanded macros and compiler syntax.\n\n",
      generate_toc(samples, categories),
      "\n",
      generate_categories(samples, categories, module)
    ]
    |> IO.iodata_to_binary()
  end

  defp generate_toc(samples, categories) do
    items =
      categories
      |> Enum.map(fn category ->
        links =
          samples
          |> Enum.filter(&(&1.category == category))
          |> Enum.map_join("\n", fn sample ->
            "  - [#{sample.title}](##{to_anchor(sample.title)})"
          end)

        "- [#{category}](##{to_anchor(category)})\n#{links}"
      end)
      |> Enum.join("\n\n")

    "## Table of Contents\n\n" <> items <> "\n"
  end

  defp generate_categories(samples, categories, module) do
    categories
    |> Enum.map(fn category ->
      category_samples = Enum.filter(samples, &(&1.category == category))

      [
        "## #{category}\n\n",
        Enum.map_join(category_samples, "\n---\n\n", &generate_sample(&1, module)),
        "\n"
      ]
    end)
  end

  defp generate_sample(sample, module) do
    expanded_ast =
      module
      |> Module.get_definition({sample.fun_name, sample.arity})
      |> definition_body()
      |> format_ast()

    """
    <a id="#{to_anchor(sample.title)}"></a>

    ### #{sample.title}

    #{sample.description}

    **Code:**
    ```elixir
    #{String.trim_trailing(sample.code)}
    ```

    **Expanded AST:**
    ```elixir
    #{expanded_ast}
    ```
    """
  end

  defp definition_body({:v1, _kind, _definition_meta, [{_clause_meta, _args, _guards, body}]}),
    do: body

  defp definition_body({:v1, _kind, _definition_meta, clauses}), do: clauses

  defp format_ast(ast), do: inspect(ast, pretty: true, limit: :infinity, width: 80)

  defp to_anchor(text) do
    anchor =
      text
      |> String.downcase()
      |> String.replace(~r/[^\w\s-]/u, "")
      |> String.replace(~r/\s+/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    if anchor == "" do
      symbol_anchor(text)
    else
      anchor
    end
  end

  defp symbol_anchor("&&"), do: "operator-and-and"
  defp symbol_anchor("||"), do: "operator-or-or"
  defp symbol_anchor("!"), do: "operator-bang"

  defp symbol_anchor(text) do
    text
    |> String.downcase()
    |> String.replace(~r/\W+/u, "-")
    |> String.trim("-")
    |> then(&if &1 == "", do: "syntax", else: &1)
  end
end

defmodule Dx.Dev.ElixirSyntaxReference do
  @moduledoc false

  use Dx.Dev.ElixirSyntaxReference.Compiler

  @my_attribute :sample_attribute

  sample "Literals", "Integer (decimal)", "Base 10 integer", code: "42" do
    42
  end

  sample "Literals", "Integer (hex)", "Hexadecimal integer", code: "0xFF" do
    0xFF
  end

  sample "Literals", "Integer (octal)", "Octal integer", code: "0o755" do
    0o755
  end

  sample "Literals", "Integer (binary)", "Binary integer", code: "0b1010" do
    0b1010
  end

  sample "Literals", "Integer (underscore)", "Integer with separators", code: "1_000_000" do
    1_000_000
  end

  sample "Literals", "Float", "Floating point number", code: "3.14159" do
    3.14159
  end

  sample "Literals", "Float (scientific)", "Scientific notation", code: "1.0e-10" do
    1.0e-10
  end

  sample "Literals", "Atom", "Named constant", code: ":hello" do
    :hello
  end

  sample "Literals", "Atom (quoted)", "Atom with special characters", code: ~S(:"hello world") do
    :"hello world"
  end

  sample "Literals", "Boolean", "Boolean atom", code: "true" do
    true
  end

  sample "Literals", "Nil", "Nil atom", code: "nil" do
    nil
  end

  sample "Literals", "String", "UTF-8 binary string", code: ~S("hello") do
    "hello"
  end

  sample "Literals", "String (interpolation)", "String interpolation",
    code: ~S("hello #{name}"),
    args: [name] do
    "hello #{name}"
  end

  sample "Literals", "String (escape)", "Escape sequence", code: ~S("line1\nline2") do
    "line1\nline2"
  end

  sample "Literals", "String (heredoc)", "Heredoc string", code: ~S("""
    hello
    world
    """) do
    """
    hello
    world
    """
  end

  sample "Literals", "Charlist", "List of codepoints", code: ~S(~c"hello") do
    ~c"hello"
  end

  sample "Literals", "Range", "Inclusive integer range", code: "1..10" do
    1..10
  end

  sample "Literals", "Range (step)", "Range with step", code: "1..10//2" do
    1..10//2
  end

  sample "Data Structures", "List", "Linked list", code: "[1, 2, 3]" do
    [1, 2, 3]
  end

  sample "Data Structures", "List (cons)", "Head/tail list construction",
    code: "[head | tail]",
    args: [head, tail] do
    [head | tail]
  end

  sample "Data Structures", "Tuple", "Fixed-size container",
    code: "{:ok, value}",
    args: [value] do
    {:ok, value}
  end

  sample "Data Structures", "Map", "Atom-keyed map", code: ~S(%{name: "Alice", age: 30}) do
    %{age: 30, name: "Alice"}
  end

  sample "Data Structures", "Map (arrow keys)", "Map with non-atom keys",
    code: ~S(%{"key" => value}),
    args: [value] do
    %{"key" => value}
  end

  sample "Data Structures", "Map (update)", "Map update syntax",
    code: "%{map | key: new_value}",
    args: [map, new_value] do
    %{map | key: new_value}
  end

  sample "Data Structures", "Keyword list", "Ordered atom-keyed list",
    code: ~S([name: "Alice", age: 30]) do
    [name: "Alice", age: 30]
  end

  sample "Data Structures", "Struct (create)", "Struct creation",
    code: ~S(%User{name: "Alice"}) do
    %Dx.Dev.ElixirSyntaxReference.User{name: "Alice"}
  end

  sample "Data Structures", "Struct (update)", "Struct update syntax",
    code: ~S(%{user | name: "Bob"}),
    args: [user] do
    %{user | name: "Bob"}
  end

  sample "Data Structures", "Binary", "Byte sequence", code: "<<1, 2, 3>>" do
    <<1, 2, 3>>
  end

  sample "Data Structures", "Bitstring", "Bit-level binary segments", code: "<<1::4, 2::4>>" do
    <<1::4, 2::4>>
  end

  sample "Data Structures", "Binary (utf8)", "UTF-8 binary segment",
    code: "<<x::utf8>>",
    args: [x] do
    <<x::utf8>>
  end

  sample "Data Structures", "Binary (size)", "Sized binary segment",
    code: "<<x::binary-size(4)>>",
    args: [x] do
    <<x::binary-size(4)>>
  end

  sample "Operators", "Arithmetic", "Arithmetic precedence",
    code: "a + b * c / d - e",
    args: [a, b, c, d, e] do
    a + b * c / d - e
  end

  sample "Operators", "Integer division", "Integer division function", code: "div(10, 3)" do
    div(10, 3)
  end

  sample "Operators", "Remainder", "Remainder function", code: "rem(10, 3)" do
    rem(10, 3)
  end

  sample "Operators", "Comparison", "Value comparison",
    code: "a == b",
    args: [a, b] do
    a == b
  end

  sample "Operators", "Strict comparison", "Strict equality",
    code: "a === b",
    args: [a, b] do
    a === b
  end

  sample "Operators", "Ordering", "Ordering operators",
    code: "a < b and c >= d",
    args: [a, b, c, d] do
    a < b and c >= d
  end

  sample "Operators", "and", "Strict boolean conjunction",
    code: "a and b",
    args: [a, b] do
    a and b
  end

  sample "Operators", "or", "Strict boolean disjunction",
    code: "a or b",
    args: [a, b] do
    a or b
  end

  sample "Operators", "not", "Strict boolean negation",
    code: "not a",
    args: [a] do
    not a
  end

  sample "Operators", "&&", "Truthy/falsy conjunction",
    code: "a && b",
    args: [a, b] do
    a && b
  end

  sample "Operators", "||", "Truthy/falsy disjunction",
    code: "a || b",
    args: [a, b] do
    a || b
  end

  sample "Operators", "!", "Truthy/falsy negation",
    code: "!a",
    args: [a] do
    !a
  end

  sample "Operators", "Boolean (strict)", "Strict boolean operators",
    code: "a and b or not c",
    args: [a, b, c] do
    (a and b) or not c
  end

  sample "Operators", "Boolean (relaxed)", "Truthy/falsy boolean operators",
    code: "a && b || !c",
    args: [a, b, c] do
    (a && b) || !c
  end

  sample "Operators", "String concat", "Binary concatenation",
    code: ~S("hello" <> " " <> "world") do
    "hello" <> " " <> "world"
  end

  sample "Operators", "List concat", "List concatenation", code: "[1, 2] ++ [3, 4]" do
    [1, 2] ++ [3, 4]
  end

  sample "Operators", "List subtract", "List subtraction", code: "[1, 2, 3] -- [2]" do
    [1, 2, 3] -- [2]
  end

  sample "Operators", "Match", "Pattern match",
    code: "{a, b} = tuple",
    args: [tuple] do
    {a, b} = tuple
    {a, b}
  end

  sample "Operators", "Pin", "Pinned pattern match",
    code: "^existing = value",
    args: [existing, value] do
    ^existing = value
  end

  sample "Operators", "Pipe", "Pipeline operator",
    code: "value |> function()",
    args: [value] do
    value |> function()
  end

  sample "Operators", "Capture (named)", "Remote function capture", code: "&String.upcase/1" do
    &String.upcase/1
  end

  sample "Operators", "Capture (anonymous)", "Anonymous capture", code: "&(&1 + &2)" do
    &(&1 + &2)
  end

  sample "Operators", "Access", "Bracket access",
    code: "data[:key]",
    args: [data] do
    data[:key]
  end

  sample "Operators", "Membership", "Membership operator",
    code: "x in [1, 2, 3]",
    args: [x] do
    x in [1, 2, 3]
  end

  sample "Operators", "Ternary-like", "Inline conditional",
    code: "if(condition, do: a, else: b)",
    args: [condition, a, b] do
    if(condition, do: a, else: b)
  end

  sample "Pattern Matching", "Variable binding", "Variable binding", code: "x = 42" do
    x = 42
    x
  end

  sample "Pattern Matching", "Tuple destructure", "Tuple destructuring",
    code: "{a, b, c} = tuple",
    args: [tuple] do
    {a, b, c} = tuple
    {a, b, c}
  end

  sample "Pattern Matching", "List destructure", "List destructuring",
    code: "[first, second | rest] = list",
    args: [list] do
    [first, second | rest] = list
    {first, second, rest}
  end

  sample "Pattern Matching", "Map destructure", "Map destructuring",
    code: "%{name: name} = map",
    args: [map] do
    %{name: name} = map
    name
  end

  sample "Pattern Matching", "Struct destructure", "Struct destructuring",
    code: "%User{name: name} = user",
    args: [user] do
    %Dx.Dev.ElixirSyntaxReference.User{name: name} = user
    name
  end

  sample "Pattern Matching", "Pin in pattern", "Pinned value inside pattern",
    code: "{^key, value} = tuple",
    args: [key, tuple] do
    {^key, value} = tuple
    value
  end

  sample "Pattern Matching", "Binary pattern", "Binary pattern match",
    code: "<<header::binary-size(4), rest::binary>> = data",
    args: [data] do
    <<header::binary-size(4), rest::binary>> = data
    {header, rest}
  end

  sample "Pattern Matching", "Ignore value", "Discarded pattern value",
    code: "{_, value} = tuple",
    args: [tuple] do
    {_, value} = tuple
    value
  end

  sample "Pattern Matching", "Named ignore", "Named ignored pattern value",
    code: "{_ignored, value} = tuple",
    args: [tuple] do
    {_ignored, value} = tuple
    value
  end

  sample "Control Flow", "case", "Pattern match branch",
    code: """
    case x do
      {:ok, val} -> val
      {:error, _} -> nil
    end
    """,
    args: [x] do
    case x do
      {:ok, val} -> val
      {:error, _} -> nil
    end
  end

  sample "Control Flow", "case (guard)", "Case branch with guards",
    code: """
    case x do
      n when n > 0 -> :positive
      n when n < 0 -> :negative
      _ -> :zero
    end
    """,
    args: [x] do
    case x do
      n when n > 0 -> :positive
      n when n < 0 -> :negative
      _ -> :zero
    end
  end

  sample "Control Flow", "cond", "Multiple conditional branches",
    code: """
    cond do
      x > 0 -> :positive
      x < 0 -> :negative
      true -> :zero
    end
    """,
    args: [x] do
    cond do
      x > 0 -> :positive
      x < 0 -> :negative
      true -> :zero
    end
  end

  sample "Control Flow", "if", "Conditional branch",
    code: """
    if condition do
      :yes
    else
      :no
    end
    """,
    args: [condition] do
    if condition do
      :yes
    else
      :no
    end
  end

  sample "Control Flow", "if (inline)", "Inline conditional",
    code: "if condition, do: :yes, else: :no",
    args: [condition] do
    if condition, do: :yes, else: :no
  end

  sample "Control Flow", "unless", "Negated conditional",
    code: """
    unless condition do
      :not_condition
    end
    """,
    args: [condition] do
    unless condition do
      :not_condition
    end
  end

  sample "Control Flow", "with", "Happy path chaining",
    code: """
    with {:ok, a} <- fetch_a(),
         {:ok, b} <- fetch_b(a) do
      {:ok, a + b}
    end
    """ do
    with {:ok, a} <- fetch_a(),
         {:ok, b} <- fetch_b(a) do
      {:ok, a + b}
    end
  end

  sample "Control Flow", "with (else)", "With fallback clauses",
    code: """
    with {:ok, val} <- fetch() do
      val
    else
      {:error, reason} -> reason
      _ -> :unknown
    end
    """ do
    with {:ok, val} <- fetch() do
      val
    else
      {:error, reason} -> reason
      _ -> :unknown
    end
  end

  sample "Error Handling", "try/rescue", "Rescue exceptions",
    code: """
    try do
      risky()
    rescue
      e in RuntimeError -> e.message
    end
    """ do
    try do
      risky()
    rescue
      e in RuntimeError -> e.message
    end
  end

  sample "Error Handling", "try/catch", "Catch thrown values",
    code: """
    try do
      throw(:ball)
    catch
      :throw, val -> val
    end
    """ do
    try do
      throw(:ball)
    catch
      :throw, val -> val
    end
  end

  sample "Error Handling", "try/after", "After cleanup clause",
    code: """
    try do
      open()
    after
      close()
    end
    """ do
    try do
      open()
    after
      close()
    end
  end

  sample "Error Handling", "raise", "Raise with message", code: ~S(raise "error message") do
    raise "error message"
  end

  sample "Error Handling", "raise (struct)", "Raise with exception struct",
    code: ~S(raise ArgumentError, message: "bad arg") do
    raise ArgumentError, message: "bad arg"
  end

  sample "Error Handling", "reraise", "Re-raise with stacktrace",
    code: """
    try do
      risky!()
    rescue
      exception -> reraise exception, __STACKTRACE__
    end
    """ do
    try do
      risky!()
    rescue
      exception -> reraise exception, __STACKTRACE__
    end
  end

  sample "Error Handling", "throw", "Throw non-local value",
    code: "throw({:early_exit, value})",
    args: [value] do
    throw({:early_exit, value})
  end

  sample "Functions", "Anonymous (fn)", "Anonymous function", code: "fn x -> x * 2 end" do
    fn x -> x * 2 end
  end

  sample "Functions", "Anonymous (multi-clause)", "Anonymous function with clauses",
    code: """
    fn
      {:ok, val} -> val
      :error -> nil
    end
    """ do
    fn
      {:ok, val} -> val
      :error -> nil
    end
  end

  sample "Functions", "Capture (remote)", "Remote function capture", code: "&String.upcase/1" do
    &String.upcase/1
  end

  sample "Functions", "Capture (local)", "Local function capture", code: "&local_fun/1" do
    &local_fun/1
  end

  sample "Functions", "Capture (partial)", "Partial anonymous capture", code: "&(&1 + &2 * &3)" do
    &(&1 + &2 * &3)
  end

  sample "Functions", "Function call", "Anonymous function call",
    code: "fun.(arg1, arg2)",
    args: [fun, arg1, arg2] do
    fun.(arg1, arg2)
  end

  sample "Comprehensions", "for (basic)", "Simple comprehension",
    code: "for x <- list, do: x * 2",
    args: [list] do
    for x <- list, do: x * 2
  end

  sample "Comprehensions", "for (filter)", "Comprehension with filter",
    code: "for x <- list, x > 0, do: x",
    args: [list] do
    for x <- list, x > 0, do: x
  end

  sample "Comprehensions", "for (multiple)", "Multiple generators",
    code: "for x <- xs, y <- ys, do: {x, y}",
    args: [xs, ys] do
    for x <- xs, y <- ys, do: {x, y}
  end

  sample "Comprehensions", "for (into)", "Comprehension into collector",
    code: "for {k, v} <- map, into: %{}, do: {k, v * 2}",
    args: [map] do
    for {k, v} <- map, into: %{}, do: {k, v * 2}
  end

  sample "Comprehensions", "for (reduce)", "Comprehension with accumulator",
    code: """
    for x <- list, reduce: 0 do
      acc -> acc + x
    end
    """,
    args: [list] do
    for x <- list, reduce: 0 do
      acc -> acc + x
    end
  end

  sample "Comprehensions", "for (uniq)", "Unique comprehension results",
    code: "for x <- list, uniq: true, do: x",
    args: [list] do
    for x <- list, uniq: true, do: x
  end

  sample "Comprehensions", "for (binary)", "Binary comprehension",
    code: "for <<byte <- binary>>, do: byte",
    args: [binary] do
    for <<byte <- binary>>, do: byte
  end

  sample "Concurrency", "receive", "Receive message",
    code: """
    receive do
      {:msg, val} -> val
    end
    """ do
    receive do
      {:msg, val} -> val
    end
  end

  sample "Concurrency", "receive (after)", "Receive with timeout",
    code: """
    receive do
      msg -> msg
    after
      1000 -> :timeout
    end
    """ do
    receive do
      msg -> msg
    after
      1000 -> :timeout
    end
  end

  sample "Concurrency", "send", "Send process message",
    code: "send(pid, {:msg, value})",
    args: [pid, value] do
    send(pid, {:msg, value})
  end

  sample "Concurrency", "spawn", "Spawn anonymous function", code: "spawn(fn -> work() end)" do
    spawn(fn -> work() end)
  end

  sample "Concurrency", "spawn (MFA)", "Spawn module-function-args",
    code: "spawn(Module, :function, [args])",
    args: [args] do
    spawn(Module, :function, [args])
  end

  sample "Concurrency", "self", "Current process", code: "self()" do
    self()
  end

  sample "Metaprogramming", "quote", "Quoted expression",
    code: """
    quote do
      1 + 2
    end
    """ do
    quote do
      1 + 2
    end
  end

  sample "Metaprogramming", "quote (unquote)", "Quoted expression with unquote",
    code: """
    quote do
      unquote(x) + 1
    end
    """,
    args: [x] do
    quote do
      unquote(x) + 1
    end
  end

  sample "Metaprogramming", "quote (unquote_splicing)", "Quoted expression with splicing",
    code: """
    quote do
      [unquote_splicing(list), last]
    end
    """,
    args: [list] do
    quote do
      [unquote_splicing(list), last]
    end
  end

  sample "Metaprogramming", "__MODULE__", "Current module", code: "__MODULE__" do
    __MODULE__
  end

  sample "Metaprogramming", "__ENV__", "Current compile environment", code: "__ENV__.file" do
    __ENV__.file
  end

  sample "Metaprogramming", "__DIR__", "Current source directory", code: "__DIR__" do
    __DIR__
  end

  sample "Metaprogramming", "__CALLER__", "Macro caller environment",
    code: "__CALLER__.line",
    kind: :defmacro do
    __CALLER__.line
  end

  sample "Metaprogramming", "__STACKTRACE__", "Current rescue stacktrace",
    code: """
    try do
      risky!()
    rescue
      _ -> __STACKTRACE__
    end
    """ do
    try do
      risky!()
    rescue
      _ -> __STACKTRACE__
    end
  end

  sample "Sigils", "~s (string)", "String sigil", code: "~s(hello world)" do
    ~s(hello world)
  end

  sample "Sigils", "~S (string raw)", "Raw string sigil", code: ~S[~S(hello\nworld)] do
    ~S(hello\nworld)
  end

  sample "Sigils", "~c (charlist)", "Charlist sigil", code: "~c(hello)" do
    ~c(hello)
  end

  sample "Sigils", "~w (word list)", "Word list sigil", code: "~w(foo bar baz)" do
    ~w(foo bar baz)
  end

  sample "Sigils", "~w (atoms)", "Atom word list sigil", code: "~w(foo bar baz)a" do
    ~w(foo bar baz)a
  end

  sample "Sigils", "~r (regex)", "Regex sigil", code: "~r/pattern/i" do
    ~r/pattern/i
  end

  sample "Sigils", "~D (date)", "Date sigil", code: "~D[2024-01-15]" do
    ~D[2024-01-15]
  end

  sample "Sigils", "~T (time)", "Time sigil", code: "~T[14:30:00]" do
    ~T[14:30:00]
  end

  sample "Sigils", "~N (naive datetime)", "Naive datetime sigil",
    code: "~N[2024-01-15 14:30:00]" do
    ~N[2024-01-15 14:30:00]
  end

  sample "Sigils", "~U (UTC datetime)", "UTC datetime sigil", code: "~U[2024-01-15 14:30:00Z]" do
    ~U[2024-01-15 14:30:00Z]
  end

  sample "Access and Updates", "Bracket access", "Access by key",
    code: "data[:key]",
    args: [data] do
    data[:key]
  end

  sample "Access and Updates", "get_in", "Nested get",
    code: "get_in(data, [:a, :b])",
    args: [data] do
    get_in(data, [:a, :b])
  end

  sample "Access and Updates", "put_in", "Nested put",
    code: "put_in(data, [:a, :b], value)",
    args: [data, value] do
    put_in(data, [:a, :b], value)
  end

  sample "Access and Updates", "update_in", "Nested update",
    code: "update_in(data, [:a, :b], &(&1 + 1))",
    args: [data] do
    update_in(data, [:a, :b], &(&1 + 1))
  end

  sample "Access and Updates", "get_and_update_in", "Nested get and update",
    code: "get_and_update_in(data, [:a], &{&1, &1 + 1})",
    args: [data] do
    get_and_update_in(data, [:a], &{&1, &1 + 1})
  end

  sample "Access and Updates", "pop_in", "Nested pop",
    code: "pop_in(data, [:a, :b])",
    args: [data] do
    pop_in(data, [:a, :b])
  end

  sample "Access and Updates", "tap", "Pipeline side-effect helper",
    code: "value |> tap(&IO.inspect/1) |> process()",
    args: [value] do
    value |> tap(&IO.inspect/1) |> process()
  end

  sample "Access and Updates", "then", "Pipeline transform helper",
    code: "value |> then(&{:ok, &1})",
    args: [value] do
    value |> then(&{:ok, &1})
  end

  sample "Module Directives", "import", "Import functions in scope",
    code: """
    import Enum, only: [map: 2]
    map([1, 2], &(&1 * 2))
    """ do
    import Enum, only: [map: 2]
    map([1, 2], &(&1 * 2))
  end

  sample "Module Directives", "alias", "Alias module name",
    code: """
    alias String, as: S
    S.upcase("hello")
    """ do
    alias String, as: S
    S.upcase("hello")
  end

  sample "Module Directives", "require", "Require macro module",
    code: """
    require Integer
    Integer.is_even(2)
    """ do
    require Integer
    Integer.is_even(2)
  end

  sample "Module Directives", "Module attribute", "Read module attribute",
    code: "@my_attribute" do
    @my_attribute
  end

  sample "Module Directives", "Block (keyword)", "Keyword block syntax",
    code: "if(true, do: :ok, else: :error)" do
    if(true, do: :ok, else: :error)
  end

  def function(value), do: value
  def local_fun(value), do: value
  def process(value), do: value
  def fetch_a, do: {:ok, 1}
  def fetch_b(value), do: {:ok, value + 1}
  def fetch, do: {:ok, 1}
  def risky, do: :ok
  def risky!, do: raise("boom")
  def open, do: :resource
  def close, do: :ok
  def work, do: :ok
end
