defmodule Test.Support.PathChecker do
  @moduledoc """

  Test.Support.PathChecker.check_file_mod_name("lib/web_svc/resolvers")

  Test.Support.PathChecker.check("test")
  Test.Support.PathChecker.check("lib", no_exs: true)

  Test.Support.PathChecker.fix("test")

  """
  @state %{fixer: nil, rules: :test, prefix: nil, filemods: %{}}

  def check(base \\ "test", opts \\ []) do
    # easier than wrangling anon function defaults
    fixer = Keyword.get(opts, :fixer, fn _, _ -> :ok end)
    state = %{Map.merge(@state, Map.new(opts)) | fixer}

    IO.puts("\n\n")

    Path.wildcard("#{base}/**/*.exs")
    |> Enum.reduce(state, &rules_for_exs(&1, &2))

    Path.wildcard("#{base}/**/*.ex")
    |> Enum.reduce(state, &rules_for_ex(&1, &2))

    IO.puts("\n\n")
  end

  ##############################################################################
  defp rules_for_exs(name, %{rules: :test} = state) do
    base = Path.basename(name, ".exs")

    cond do
      should_ignore?(base) ->
        state

      is_support?(base) ->
        stateful_log("EXS file found in support folder: #{name}", state)

      is_test?(base) ->
        check_test(name, state)

      is_migration?(base) ->
        check_migration(name, state)

      true ->
        stateful_log(
          "SKIPPING #{name} (test?=#{is_test?(base)} #{String.slice(base, -5..-1//1)})",
          state
        )
    end
  end

  defp rules_for_exs(name, %{no_exs: true} = s),
    do: stateful_log("EXS file found: #{name}", s)

  defp rules_for_exs(path, state) do
    {_base, _mod, _filemod} = breakdown(path, state)
    state
  end

  ##############################################################################
  defp rules_for_ex(name, %{rules: :test} = s) do
    cond do
      is_support?(name) -> check_support(name, s)
      is_migration?(name) -> stateful_log("EX file found in migrations folder: #{name}", s)
      is_test?(name) -> stateful_log("EX file found outside of support folder: #{name}", s)
      true -> stateful_log("EX file where it should be EXS, is it wrongly named? #{name}", s)
    end
  end

  defp rules_for_ex(path, state) do
    {_base, _mod, _filemod} = breakdown(path, state)

    state
  end

  ##############################################################################
  # just for aesthetics
  defp stateful_log(msg, state) do
    IO.puts(msg)
    state
  end

  def fix(path), do: check(path, fixer: &fixins/2)

  def check_file_mod_name(base \\ "lib", fixer \\ nil) do
    IO.puts("\n\n")

    (Path.wildcard("#{base}/**/*.exs") ++ Path.wildcard("#{base}/**/*.ex"))
    |> Enum.each(fn name ->
      breakdown(name, %{fixer})
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
      put_in(state, [Access.key(:filemods, %{}), filemod], path)
    end

    state
  end

  ##############################################################################
  defp check_support(path, state) do
    {base, _mod, _filemod} = breakdown(path, state)

    if is_test?(base) do
      IO.puts("FILE ENDS IN _test in support folder?: #{path}")
    end

    state
  end

  ##############################################################################
  defp check_test(path, state) do
    {base, _mod, _filemod} = breakdown(path, state)

    # doesn't end with test
    if not is_test?(base) do
      IO.puts("TEST FILE DOES NOT END IN _test: #{path}")
    end

    state
  end

  ##############################################################################
  defp index_rx(), do: ~r{/(index|model)$}
  defp strip_ts_rx(), do: ~r{/[0-9]+_}
  defp breakdown(path, state) do
    [p, _suffix] = String.split(path, ".")
    p = if Regex.match?(index_rx(), p), do: Regex.replace(index_rx(), p, ""), else: p
    p = if is_migration?(p), do: Regex.replace(strip_ts_rx(), p, "/"), else: p
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
      state.fixer.(:dash, path: path)
    end

    # no match
    mod = add_mod_prefix(state, mod)
    if "#{mod}" != "#{filemod}" and not ignore? do
      IO.puts("FILE/MODULE Mis-Match in #{path} Should be: #{mod} not #{filemod}")

      if not is_nil(state.fixer),
        do: state.fixer.(:mod_name, path: path, old: filemod, new: mod, data: data)
    end

    {p, mod, filemod}
  end

  defp add_mod_prefix(%{prefix: nil}, mod), do: mod
  defp add_mod_prefix(%{prefix}, mod), do: "#{prefix}.#{mod}"

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
