defmodule Test.Support.DateTimeHelpers do
  @moduledoc """
  DateTime helpers for seeding and tests
  """

  alias Test.Support.TimeUtils

  # get today or today +/- some days eg: yesterday = today(-1)
  def monday, do: ~D[2018-01-01]
  def monday(days) when is_integer(days), do: Date.add(monday(), days)
  def monday(%Time{} = time), do: datetime(monday(), time)
  def monday(%Time{} = time, timezone), do: DateTime.new!(monday(), time, timezone)

  def monday(days, %Time{} = time) when is_integer(days),
    do: datetime(monday(days), time)

  def monday(days, %Time{} = time, timezone) when is_integer(days) and is_binary(timezone),
    do: DateTime.new!(monday(days), time, timezone)

  def today, do: TimeUtils.today()
  def today(timezone) when is_binary(timezone), do: TimeUtils.today(timezone)
  def today(days) when is_integer(days), do: Date.add(today(), days)
  def today(%Time{} = time), do: datetime(today(), time)

  def today(days, %Time{} = time) when is_integer(days),
    do: datetime(today(days), time)

  def today(days, timezone) when is_integer(days) and is_binary(timezone),
    do: Date.add(today(timezone), days)

  def today(%Time{} = time, timezone) when is_binary(timezone),
    do: today(timezone) |> DateTime.new!(time, timezone)

  def today(days, %Time{} = time, timezone) when is_integer(days) and is_binary(timezone),
    do: datetime(today(days, timezone), time)

  def datetime(%Date{} = date, %Time{} = time) do
    {:ok, datetime} = NaiveDateTime.new(date, time)
    datetime |> DateTime.from_naive!("Etc/UTC")
  end

  def we_date(days_offset) when is_integer(days_offset) do
    we_date(Date.utc_today(), 7, days_offset)
  end

  def we_date(days_offset, %Time{} = time) when is_integer(days_offset) do
    we_date(Date.utc_today(), 7, days_offset)
    |> DateTime.new!(time)
  end

  def we_date(%Date{} = date, days_offset) do
    we_date(date, 7, days_offset)
  end

  def we_date(%Date{} = date, week_ending_day, days_offset) do
    day_number = Date.day_of_week(date)
    # find the number of days until the coming end of week day
    day_diff = rem(7 + week_ending_day - day_number, 7)

    Date.add(date, day_diff)
    |> TimeUtils.shift!(days: days_offset)
  end

  @doc """
  convert a Date or Time struct to the select format
  """
  def to_params(%Time{} = time) do
    %{
      "hour" => Integer.to_string(time.hour),
      "minute" => Integer.to_string(time.minute)
    }
  end

  def to_params(%Date{} = date) do
    %{
      "day" => Integer.to_string(date.day),
      "month" => Integer.to_string(date.month),
      "year" => Integer.to_string(date.year)
    }
  end

  def to_params(%DateTime{} = dt) do
    %{
      "day" => Integer.to_string(dt.day),
      "month" => Integer.to_string(dt.month),
      "year" => Integer.to_string(dt.year),
      "hour" => Integer.to_string(dt.hour),
      "minute" => Integer.to_string(dt.minute)
    }
  end
end
