defmodule Test.Support.DateTimeHelpers do
  @moduledoc """
  DateTime helpers for tests
  """

  # get today with optional offset in days, with optional time, e.g. yesterday = today(-1)
  def today, do: Date.utc_today()
  def today(days_offset) when is_integer(days_offset), do: Date.add(today(), days_offset)
  def today(%Time{} = time), do: DateTime.new!(today(), time)

  def today(days_offset, %Time{} = time) when is_integer(days_offset),
    do: DateTime.new!(today(days_offset), time)
end
