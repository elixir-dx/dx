defmodule Dx.Test.DefdCase do
  use ExUnit.CaseTemplate

  defmacro __using__(opts) do
    quote do
      use Dx.Test.DataCase, unquote(opts)

      import Dx.Test.DefdCase.Helpers

      import Dx.Defd, except: [defd: 1, defd: 2]
    end
  end

  defmodule Helpers do
    defmacro location(plus) do
      file = Path.relative_to_cwd(__CALLER__.file)
      quote do: "#{unquote(file)}:#{unquote(__CALLER__.line) + unquote(plus)}"
    end

    def refute_stderr(fun) do
      output = ExUnit.CaptureIO.capture_io(:stderr, fun)

      assert output == "", """
      Expected no compiler warnings, but got:

      #{output}
      """
    end

    def refute_stderr(msg_part, fun) do
      output = ExUnit.CaptureIO.capture_io(:stderr, fun)

      refute output =~ msg_part, """
      Expected stderr not to contain #{inspect(msg_part)}, but got:

      #{output}
      """
    end

    def assert_stderr(msg_part, fun) do
      output = ExUnit.CaptureIO.capture_io(:stderr, fun)

      assert output =~ msg_part, """
      Expected stderr to contain #{inspect(msg_part)}, but got:

      #{output}
      """
    end

    def assert_same_error(expected_types, location, fun1, fun2) do
      {e1, e2} = {get_error_and_stacktrace(fun1), get_error_and_stacktrace(fun2)}
      assert e1 == e2

      assert {:error, _, type, _, stacktrace} = e1
      assert type in List.wrap(expected_types)

      assert Enum.any?(stacktrace, &String.starts_with?(&1, location)), """
      No stacktrace entry starts with #{location}

      #{Enum.join(stacktrace, "\n")}
      """
    end

    defp get_error_and_stacktrace(fun) do
      {:ok, fun.()}
    rescue
      e -> {:error, e, e.__struct__, Exception.message(e), stacktrace(__STACKTRACE__)}
    end

    defp stacktrace(stacktrace) do
      stacktrace
      |> Exception.format_stacktrace()
      |> String.split("\n", trim: true)
      |> Enum.map(&String.trim_leading/1)
    end
  end
end
