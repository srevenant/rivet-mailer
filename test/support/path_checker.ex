defmodule Test.Support.PathChecker do
  @moduledoc """

  Test.Support.PathChecker.check_file_mod_name("lib/web_svc/resolvers")
  Test.Support.PathChecker.check("test")
  Test.Support.PathChecker.fix("test")

  """

  def check(base \\ "test", fixer \\ fn _, _ -> :ok end) do
    IO.puts("\n\n")

    Path.wildcard("#{base}/**/*.exs")
    |> Enum.reduce(%{}, fn name, state ->
      base = Path.basename(name, ".exs")

      cond do
        should_ignore?(base) ->
          state

        is_support?(base) ->
          IO.puts("EXS file found in support folder: #{name}")
          state

        is_test?(base) ->
          check_test(name, fixer)
          state

        is_migration?(base) ->
          check_migration(name, state)

        true ->
          IO.puts("SKIPPING #{name} (test?=#{is_test?(base)} #{String.slice(base, -5..-1//1)})")
      end
    end)

    Path.wildcard("#{base}/**/*.ex")
    |> Enum.each(fn name ->
      cond do
        is_support?(name) -> check_support(name, fixer)
        is_migration?(name) -> IO.puts("EX file found in migrations folder: #{name}")
        is_test?(name) -> IO.puts("EX file found outside of support folder: #{name}")
        true -> IO.puts("EX file where it should be EXS, is it wrongly named? #{name}")
      end
    end)

    IO.puts("\n\n")
  end

  def fix(path) do
    check(path, &fixins/2)
  end

  def check_file_mod_name(base \\ "lib", fixer \\ nil) do
    IO.puts("\n\n")

    (Path.wildcard("#{base}/**/*.exs") ++ Path.wildcard("#{base}/**/*.ex"))
    |> Enum.each(fn name ->
      breakdown(name, fixer)
    end)

    IO.puts("\n\n")
  end

  def fix_file_mod_name(base \\ "lib") do
    check_file_mod_name(base, &fixins/2)
  end

  ##############################################################################
  defp check_migration(path, state) do
    {_base, mod, filemod} = breakdown(path, nil)

    if Map.has_key?(state, filemod) do
      IO.puts("DUPLICATE MIGRATION #{path} vs #{state[mod]}")
      state
    else
      Map.put(state, filemod, path)
    end
  end

  ##############################################################################
  defp check_support(path, fixer) do
    {base, _mod, _filemod} = breakdown(path, fixer)

    if is_test?(base) do
      IO.puts("FILE ENDS IN _test in support folder?: #{path}")
    end
  end

  ##############################################################################
  defp check_test(path, fixer) do
    {base, _mod, _filemod} = breakdown(path, fixer)

    # doesn't end with test
    if not is_test?(base) do
      IO.puts("TEST FILE DOES NOT END IN _test: #{path}")
    end
  end

  ##############################################################################
  @index_rx ~r{/index$}
  @strip_ts_rx ~r{/[0-9]+_}
  defp breakdown(path, fixer) do
    [p, _suffix] = String.split(path, ".")
    p = if Regex.match?(@index_rx, p), do: Regex.replace(@index_rx, p, ""), else: p
    p = if is_migration?(p), do: Regex.replace(@strip_ts_rx, p, "/"), else: p
    p = Regex.replace(~r{^lib/}, p, "")

    mod = Transmogrify.Modulename.convert(p)
    {:ok, data} = File.read(path)
    [first | _] = String.split(data, "\n")

    filemod =
      first
      |> String.replace(~r/defmodule /, "")
      |> String.replace(~r/ do$/, "")

    ignore? = should_ignore?(path)

    # Only checks in common here
    if String.contains?(path, "-") and not ignore? do
      IO.puts("NAME INCLUDES A DASH! #{path}")
      fixer.(:dash, path: path)
    end

    # no match
    if "#{mod}" != "#{filemod}" and not ignore? do
      IO.puts("FILE/MODULE Mis-Match in #{path} Should be: #{mod} not #{filemod}")
      if not is_nil(fixer), do: fixer.(:mod_name, path: path, old: filemod, new: mod, data: data)
    end

    {p, mod, filemod}
  end

  defp fixins(:dash, _), do: :ok

  defp fixins(:mod_name, args) do
    args = Map.new(args)
    File.write(args.path, Regex.replace(~r/#{args.old}/, args.data, args.new))
  end

  defp is_test?(base), do: String.slice(base, -5..-1//1) == "_test"
  defp is_support?(p), do: String.contains?(p, "test/support")
  defp is_migration?(p), do: String.contains?(p, "repo/migration")

  defp should_ignore?(p),
    do: String.slice(p, 0..17//1) == "test/support/rivet" or String.contains?(p, "test_helper")
end
