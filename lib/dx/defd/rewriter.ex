defmodule Dx.Defd.Rewriter do
  @moduledoc """
  Used to define modules as replacements for specific other modules
  within functions defined with defd.

  ## Examples

  ### Overriding specific functions

  Every function defined using `defd` or `defd_` will act as a
  replacement for a function with the same name and arity called
  in a function defined with defd.

      defmodule Dx.Enum do
        use Dx.Defd.Rewriter

        defd_ load_if(record, load?, field) do
          if load? do
            if Ecto.assoc_loaded?(record, field) do
              {:ok, Map.get(record, field)}
            else
              {:not_loaded, {:assoc, record, field}}
            end
          else
            {:ok, record}
          end
        end
      end

  ### Delegating some or all functions

      defmodule Dx.Timex do
        use Dx.Defd.Rewriter,
          delegate_to: [
            DateTime,
            {Timex, except: [inspect: 2]}
          ]
      end

  ### Delegating specific functions

      defmodule Dx.Phoenix do
        use Dx.Defd.Rewriter

        defdelegated_call render(template, opts), to:
      end
  """

  @doc false
  defmacro __using__(opts) do
    quote location: :keep, bind_quoted: [opts: opts] do
      @behaviour GenServer

      unless Module.has_attribute?(__MODULE__, :doc) do
        @doc """
        Returns a specification to start this module under a supervisor.

        See `Supervisor`.
        """
      end

      def child_spec(init_arg) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [init_arg]}
        }

        Supervisor.child_spec(default, unquote(Macro.escape(opts)))
      end

      defoverridable child_spec: 1
    end
  end
end
