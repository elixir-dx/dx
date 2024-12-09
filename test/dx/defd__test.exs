defmodule Dx.Defd_Test do
  use ExUnit.Case, async: true

  alias Dx.Defd_.ArgInfo
  alias Dx.Defd_.FunInfo

  doctest FunInfo, import: true

  describe "__dx_fun_info/2 callback" do
    import Dx.Defd.Util, only: [fun_info: 3]

    test "returns plain FunInfo by default" do
      defmodule PlainTest do
        use Dx.Defd_

        defd_ bool_constant() do
          {:ok, true}
        end
      end

      assert %FunInfo{args: []} = fun_info(PlainTest, :bool_constant, 0)
    end

    test "with multiple arguments and different configurations" do
      defmodule MultiArgsTest do
        use Dx.Defd_

        @dx_ args: %{0 => :preload_scope, 1 => :fn, 2 => [:preload_scope, :fn]}
        defd_ process(data, _transformer, _callback) do
          {:ok, data}
        end
      end

      assert %FunInfo{
               args: [
                 %ArgInfo{preload_scope: true},
                 %ArgInfo{preload_scope: false, fn: %FunInfo{}},
                 %ArgInfo{preload_scope: true, fn: %FunInfo{}}
               ]
             } = fun_info(MultiArgsTest, :process, 3)
    end

    test "@dx_ overrides @moduledx_" do
      defmodule OverrideTest do
        use Dx.Defd_

        @moduledx_ args: %{all: :preload_scope}

        @dx_ args: %{1 => :fn}
        defd_ transform(input, _mapper) do
          {:ok, input}
        end
      end

      assert %FunInfo{
               args: [
                 %ArgInfo{preload_scope: false},
                 %ArgInfo{preload_scope: false, fn: %FunInfo{}}
               ]
             } = fun_info(OverrideTest, :transform, 2)
    end

    test "with nested function arguments" do
      defmodule NestedFunTest do
        use Dx.Defd_

        @dx_ args: %{
               0 => :preload_scope,
               1 => {:fn, args: %{0 => :preload_scope}, arity: 1},
               2 => {:fn, args: %{all: :fn}, arity: 1}
             }
        defd_ nested(data, _mapper, _reducer) do
          {:ok, data}
        end
      end

      assert %FunInfo{
               args: [
                 %ArgInfo{preload_scope: true},
                 %ArgInfo{
                   preload_scope: false,
                   fn: %FunInfo{
                     args: [%ArgInfo{preload_scope: true}]
                   }
                 },
                 %ArgInfo{
                   preload_scope: false,
                   fn: %FunInfo{
                     args: [%ArgInfo{fn: %FunInfo{}}]
                   }
                 }
               ]
             } = fun_info(NestedFunTest, :nested, 3)
    end

    test "returns @moduledx_ if defined" do
      defmodule Moduledx_Test do
        use Dx.Defd_

        @moduledx_ args: %{all: :preload_scope}

        defd_ run(enum) do
          Dx.Enum.map(enum, & &1)
        end
      end

      assert %FunInfo{args: [%ArgInfo{preload_scope: true}]} =
               fun_info(Moduledx_Test, :run, 1)
    end

    test "with default args" do
      defmodule DefaultArgsTest do
        use Dx.Defd_

        @moduledx_ args: %{all: :preload_scope}

        @dx_ args: %{0 => :preload_scope, 1 => :fn}
        defd_ run(enum, mapper \\ nil) do
          if mapper do
            Dx.Enum.map(enum, mapper)
          else
            {:ok, enum}
          end
        end
      end

      assert %FunInfo{
               args: [
                 %ArgInfo{preload_scope: true}
               ]
             } = fun_info(DefaultArgsTest, :run, 1)

      assert %FunInfo{
               args: [
                 %ArgInfo{preload_scope: true},
                 %ArgInfo{fn: %FunInfo{}, preload_scope: false}
               ]
             } = fun_info(DefaultArgsTest, :run, 2)
    end
  end
end
