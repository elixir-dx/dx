defmodule Test.Support.TimeUtils do
  @moduledoc """
  Time/date utils
  """

  @default_timezone "Europe/London"

  @doc """
  returns the current date in the given timezone
  """
  def today(timezone \\ @default_timezone) do
    DateTime.now!(timezone) |> DateTime.to_date()
  end

  def timezone, do: @default_timezone

  def shift!(any, opts) do
    case Timex.shift(any, opts) do
      {:error, reason} ->
        raise(ArgumentError, """
        Invalid call: Timex.shift(#{inspect(any)}, #{inspect(opts)})
        reason: #{inspect(reason)}
        """)

      shifted ->
        shifted
    end
  end

  def utc_now_truncated do
    DateTime.utc_now() |> DateTime.truncate(:second)
  end

  def utc_now_string do
    DateTime.utc_now() |> DateTime.to_string()
  end

  @doc """
  builds a sets the Time in a DateTime from a DateTime and Time

  iex>new_datetime(~U[2018-01-01 10:00:00.000Z], ~T[00:00:00.000])
  ~U[2018-01-01 00:00:00.000Z]
  """
  def new_datetime(%DateTime{} = dt, %Time{} = t) do
    Map.merge(dt, Map.from_struct(t))
  end

  @doc """
  convert the naive or utc datetime to the configured default timezone
  """
  def localise(datetime, timezone \\ @default_timezone)

  def localise(%NaiveDateTime{} = naivedatetime, timezone) do
    naivedatetime
    |> to_utc!
    |> localise(timezone)
  end

  def localise(%DateTime{} = datetime, timezone) do
    datetime |> DateTime.shift_zone!(timezone)
  end

  @doc """
  convert
    1, date, time
    2, NaiveDateTime
  to utc datetime
  """
  def to_utc!(%NaiveDateTime{} = naivedatetime) do
    DateTime.from_naive!(naivedatetime, "Etc/UTC")
  end

  def to_utc!({:ok, %NaiveDateTime{} = naivedatetime}) do
    DateTime.from_naive!(naivedatetime, "Etc/UTC")
  end

  def to_utc!(%Date{} = date, %Time{} = time) do
    date
    |> NaiveDateTime.new(time)
    |> to_utc!()
  end

  @doc """
  convert
    1, date, time
  to naive datetime
  """
  def to_naive!(%Date{} = date, %Time{} = time) do
    {:ok, date} = NaiveDateTime.new(date, time)

    date
  end

  @doc """
  the unix time for the current second
  """
  def unix_now,
    do: DateTime.utc_now() |> DateTime.to_unix()

  @doc """
  Convert number seconds to nearest whole minute
  iex> seconds_to_mins(10)
  0
  iex> seconds_to_mins(30)
  1
  iex> seconds_to_mins(60)
  1
  iex> seconds_to_mins(89)
  1
  """
  def seconds_to_mins(seconds),
    do: round(seconds / 60)

  @doc """
  Convert number minutes to nearest whole hour
  iex> round_mins_to_hours(10, round_direction: :nearest)
  0
  iex> round_mins_to_hours(30, round_direction: :nearest)
  1
  iex> round_mins_to_hours(60, round_direction: :nearest)
  1
  iex> round_mins_to_hours(10, round_direction: :up)
  1
  iex> round_mins_to_hours(60, round_direction: :up)
  1
  """
  def round_mins_to_hours(mins, _ops) when mins < 0,
    do: raise("round_mins_to_hours not implemented for negative values - got: #{mins}")

  def round_mins_to_hours(nil, _ops),
    do: nil

  def round_mins_to_hours(mins, round_direction: :up),
    do: mins |> Kernel./(60) |> Float.ceil() |> Kernel.trunc()

  def round_mins_to_hours(mins, round_direction: :nearest),
    do: mins |> Kernel./(60) |> Kernel.round()

  @doc """
  takes earliest from two datetimes/dates

  iex> take_earliest(~D[2018-01-01], ~D[2018-01-02])
  ~D[2018-01-01]
  """
  def take_earliest(a, b) do
    if Timex.before?(a, b), do: a, else: b
  end

  @doc """
  takes latest from two datetimes/dates

  iex> take_latest(~D[2018-01-01], ~D[2018-01-02])
  ~D[2018-01-02]
  """
  def take_latest(a, b) do
    if Timex.before?(a, b), do: b, else: a
  end

  @doc """
  checks if datetime is before a given Time on the same date as datetime

  iex> is_before?(~U[2020-01-01 07:00:00Z], ~T[08:00:00])
  true
  """
  def is_before?(%DateTime{} = datetime_1, %Time{} = time_2),
    do: DateTime.compare(datetime_1, new_datetime(datetime_1, time_2)) == :lt

  def is_before?(a, b), do: Timex.before?(a, b)

  @doc """
  check if the two dates or datetimes are the same
  """
  def same_date?(a, b), do: Timex.equal?(Timex.to_date(a), Timex.to_date(b))

  @doc """
  checks if two datetimes are on consecutive days.
  use :midnight_is_next_day if midnight on the following day should considered spanning two days
  use :midnight_is_same_day if midnight on the following day should not be considered spanning two days
  """
  def spans_two_days?(%DateTime{} = dt1, %DateTime{} = dt2, :midnight_is_same_day) do
    same_date?(dt1, Timex.shift(dt2, days: -1)) and not midnight?(dt2)
  end

  def spans_two_days?(%DateTime{} = dt1, %DateTime{} = dt2, :midnight_is_next_day) do
    same_date?(dt1, Timex.shift(dt2, days: -1))
  end

  @doc """
  check if datetime is midnight
  """
  def midnight?(datetime) do
    datetime |> DateTime.to_time() |> Time.compare(~T[00:00:00]) == :eq
  end

  @doc """
  get number of mins past midnight
  """
  def mins_past_midnight(datetime) do
    midnight = Timex.beginning_of_day(datetime)
    Timex.diff(datetime, midnight, :minutes)
  end

  @doc """
  get number of mins past a certain time
  mins_past_time(#DateTime<-2019-01-21 04:30:00Z>, ~T[03:00:00])
  90
  """
  def mins_past_time(datetime, time) do
    base_datetime =
      datetime
      |> Timex.beginning_of_day()
      |> Timex.shift(hours: time.hour, minutes: time.minute, seconds: time.second)

    Timex.diff(base_datetime, datetime, :seconds) |> seconds_to_mins()
  end

  @doc """
  get number of mins until certain time
  mins_until_time(#DateTime<-2019-01-21 04:30:00Z>, ~T[05:00:00])
  30
  mins_until_time(#DateTime<-2019-01-21 04:30:00Z>, ~T[04:00:00])
  -30
  """
  def mins_until_time(datetime, time) do
    until_datetime =
      datetime
      |> Timex.beginning_of_day()
      |> Timex.shift(hours: time.hour, minutes: time.minute, seconds: time.second)

    Timex.diff(datetime, until_datetime, :seconds) |> seconds_to_mins()
  end

  @doc """
  Adds a week to a given date
  """
  def add_week(date_or_datetime), do: Timex.shift(date_or_datetime, days: 7)

  @doc """
  Goes back a week from a given date_or_datetime
  """
  def minus_week(date_or_datetime), do: Timex.shift(date_or_datetime, days: -7)

  def minus_week_if(date_or_datetime, true), do: minus_week(date_or_datetime)
  def minus_week_if(date_or_datetime, false), do: date_or_datetime

  @doc """
  Goes back to the first day of a week given its week ending date
  """
  def beginning_of_week(we_date), do: Timex.shift(we_date, days: -6)

  @doc """
  check if date is in future
  """
  def in_future?(%Date{} = date, timezone), do: Date.compare(date, today(timezone)) == :gt
  def in_future?(%Date{} = date), do: Date.compare(date, today()) == :gt

  def in_future?(%DateTime{} = datetime),
    do: DateTime.compare(datetime, DateTime.utc_now()) == :gt

  def in_future?(%NaiveDateTime{} = datetime),
    do: NaiveDateTime.compare(datetime, NaiveDateTime.utc_now()) == :gt

  @doc """
  check if date is in the past
  """
  def in_past?(%Date{} = date, timezone), do: Date.compare(date, today(timezone)) == :lt
  def in_past?(%Date{} = date), do: Date.compare(date, today()) == :lt
  def in_past?(%DateTime{} = datetime), do: DateTime.compare(datetime, DateTime.utc_now()) == :lt

  def in_past?(%NaiveDateTime{} = datetime),
    do: NaiveDateTime.compare(datetime, NaiveDateTime.utc_now()) == :lt

  @doc """
  overlap gets the number of units of time in one time range that overlap with another, defaults
  to minutes.

  iex> range_start = ~U[2018-01-01 10:00:00.000Z]
  iex> range_end = ~U[2018-01-01 11:00:00.000Z]
  iex> overlap(~U[2018-01-01 09:00:00.000Z], ~U[2018-01-01 09:30:00.000Z], range_start, range_end)
  0
  iex> overlap(~U[2018-01-01 11:30:00.000Z], ~U[2018-01-01 12:30:00.000Z], range_start, range_end)
  0
  iex> overlap(~U[2018-01-01 09:00:00.000Z], ~U[2018-01-01 10:30:00.000Z], range_start, range_end)
  30
  iex> overlap(~U[2018-01-01 10:30:00.000Z], ~U[2018-01-01 12:00:00.000Z], range_start, range_end)
  30
  iex> overlap(~U[2018-01-01 10:15:00.000Z], ~U[2018-01-01 10:45:00.000Z], range_start, range_end)
  30
  iex> overlap(~U[2018-01-01 09:00:00.000Z], ~U[2018-01-01 12:00:00.000Z], range_start, range_end)
  60
  """
  def overlap(
        range_1_start,
        range_1_end,
        range_2_start,
        range_2_end,
        unit \\ :minutes
      ) do
    start = take_latest(range_1_start, range_2_start)
    finish = take_earliest(range_1_end, range_2_end)

    cond do
      # range 2 entirely after range 1
      Timex.before?(range_1_end, range_2_start) -> 0
      # range 2 entirely before range 1
      Timex.after?(range_1_start, range_2_end) -> 0
      true -> Timex.diff(finish, start, unit)
    end
  end

  @doc """
  Generate the 7 dates of the week prior to week ending date
  """
  def week_date_range(%Date{} = we_date) do
    we_date
    |> Date.add(-6)
    |> Date.range(we_date)
  end
end
