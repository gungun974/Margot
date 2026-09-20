-module(margot_format_ffi).

-export([format_gleam_code/1]).

format_gleam_code(Code) ->
    GleamExe = case os:find_executable("gleam") of
        false -> "gleam";
        Path -> Path
    end,
    File = filename:join(
        temp_dir(),
        "margot_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".gleam"
    ),
    try
        ok = file:write_file(File, unicode:characters_to_binary(Code)),
        Port = open_port(
            {spawn_executable, GleamExe},
            [binary, exit_status, stderr_to_stdout, {args, ["format", File]}]
        ),
        case wait(Port) of
            0 ->
                case file:read_file(File) of
                    {ok, Formatted} -> {ok, unicode:characters_to_binary(Formatted)};
                    _ -> {error, nil}
                end;
            _ ->
                {error, nil}
        end
    catch
        _:_ -> {error, nil}
    after
        file:delete(File)
    end.

temp_dir() ->
    temp_dir(["TMPDIR", "TMP", "TEMP"]).

temp_dir([]) -> "/tmp";
temp_dir([Var | Rest]) ->
    case os:getenv(Var) of
        false -> temp_dir(Rest);
        "" -> temp_dir(Rest);
        Dir -> Dir
    end.

wait(Port) ->
    receive
        {Port, {data, _}} -> wait(Port);
        {Port, {exit_status, Status}} -> Status
    after 10000 ->
        catch port_close(Port),
        error
    end.
