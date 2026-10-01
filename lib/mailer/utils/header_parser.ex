defmodule Rivet.Mailer.Utils.HeaderParser do
  @moduledoc """

  Lightweight email header parser, without all the :mimemail overhead

  * CRLF and LF are both handled, no need to pre-process
  * Lowercases header names for uniformity
  * Handles multi-line continuation
  * Values returned in key/value map, where values are always a list (even of one)
  * Performs no MIME or charset decoding
  * also handles the unix mbox From_... separator/envelope first line

  """
  alias __MODULE__

  defstruct headers: %{}, only: false, body: nil

  @type headers :: %{optional(binary()) => [binary()]}
  @type t :: %__MODULE__{
          headers: headers(),
          only: false | [binary()],
          body: binary() | nil
        }

  @spec extract(binary(), keyword()) :: {:ok, t()} | {:error, term()}
  def extract(data, opts \\ []) when is_binary(data) do
    only =
      case Keyword.get(opts, :only, false) do
        false -> false
        <<name::binary>> -> [String.downcase(name)]
        names when is_list(names) -> Enum.map(names, &String.downcase/1)
      end

    strip_mbox_from(data)
    |> parse_lines(nil, %HeaderParser{only})
    |> finish_result()
  end

  defp finish_result({:ok, %HeaderParser{} = p, body}), do: {:ok, %{p | body}}
  defp finish_result(pass), do: pass

  # # # # # # # # #
  defp strip_mbox_from(<<"From ", _::binary>> = data) do
    {_, rest} = next_line(data)
    rest
  end

  defp strip_mbox_from(data), do: data

  # # # # # # # # #
  defp parse_lines("", current, %HeaderParser{} = p), do: {:ok, put_header(current, p), ""}

  defp parse_lines(data, current, %HeaderParser{} = p),
    do: data |> next_line() |> parse_line_(current, p)

  # # # # # # # # #
  defp parse_line_({"", rest}, current, %HeaderParser{} = p),
    do: {:ok, put_header(current, p), rest}

  defp parse_line_({<<c, _::binary>> = line, rest}, current, %HeaderParser{} = p)
       when c in [?\s, ?\t] do
    case current do
      nil -> {:error, :unexpected_continuation}
      {name, values} -> parse_lines(rest, {name, [String.trim(line) | values]}, p)
    end
  end

  defp parse_line_({line, rest}, current, %HeaderParser{} = p),
    do: parse_header(current, line, rest, p)

  # # # # # # # # #
  defp parse_header(current, line, rest, %HeaderParser{} = p) do
    case String.split(line, ":", parts: 2) do
      [name, value] ->
        name = name |> String.trim() |> String.downcase()

        if name == "" do
          {:error, :empty_header_name}
        else
          p = put_header(current, p)
          parse_lines(rest, {name, [String.trim(value)]}, p)
        end

      _ ->
        {:error, :malformed_header}
    end
  end

  # # # # # # # # #
  defp put_header(nil, %HeaderParser{} = p), do: p

  defp put_header({name, values}, %HeaderParser{} = p) do
    if p.only == false or name in p.only do
      value = values |> Enum.reverse() |> Enum.join(" ")
      %{p | headers: Map.update(p.headers, name, [value], &(&1 ++ [value]))}
    else
      p
    end
  end

  # # # # # # # # #
  defp next_line(data) do
    case :binary.split(data, "\n") do
      [line, rest] -> {String.trim_trailing(line, "\r"), rest}
      [line] -> {line, ""}
    end
  end

  ##############################################################################
  @spec parse_params(binary()) :: {binary(), map()}
  # def parse_params(""), do: {"", %{}}
  def parse_params(value) do
    [value | params] =
      Regex.split(~r/;\s*(?=(?:[^"]*"[^"]*")*[^"]*$)/, value)

    params =
      Map.new(params, fn param ->
        case String.split(param, "=", parts: 2) do
          [name, value] ->
            {String.downcase(String.trim(name)), dequote(String.trim(value))}

          [name] ->
            {String.downcase(String.trim(name)), ""}
        end
      end)

    {String.trim(value), params}
  end

  defp dequote(value) do
    if String.starts_with?(value, "\"") and String.ends_with?(value, "\"") do
      String.slice(value, 1, String.length(value) - 2)
    else
      value
    end
  end
end
