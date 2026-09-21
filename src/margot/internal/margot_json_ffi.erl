-module(margot_json_ffi).

-export([parse_string/1]).

-if(?OTP_RELEASE < 27).
-define(bad_version,
    error({erlang_otp_27_required, << "Insufficient Erlang/OTP version.

Reading a `.i18n.json` file needs the Erlang `json` module introduced in Erlang/OTP 27.
You are using Erlang/OTP "/utf8, (integer_to_binary(?OTP_RELEASE))/binary, "
Please upgrade your Erlang install or use another file type (YAML, TOML or CSV).
"/utf8>>})).

parse_string(_) -> ?bad_version.
-else.

parse_string(String) ->
    try
        Decoders = #{
            object_finish => fun(Acc, OldAcc) -> {{object, lists:reverse(Acc)}, OldAcc} end
        },
        case json:decode(String, ok, Decoders) of
            {Value, ok, Rest} ->
                case string:trim(Rest, leading, [$\s, $\t, $\r, $\n]) of
                    <<>> -> {ok, map_json_value(Value)};
                    <<First, _/binary>> -> {error, invalid_byte_error(First)}
                end
        end
    catch
        error:unexpected_end ->
            {error, {parsing_error, <<"unexpected end of input">>, none}};
        error:{invalid_byte, Byte} ->
            {error, invalid_byte_error(Byte)};
        error:{unexpected_sequence, Sequence} ->
            {error, {parsing_error, <<"unexpected sequence ", Sequence/binary>>, none}};
        error:_ ->
            {error, unexpected_parsing_error}
    end.

invalid_byte_error(Byte) when Byte >= 33, Byte =< 126 ->
    {parsing_error, <<"unexpected `", Byte, "`">>, none};
invalid_byte_error(Byte) ->
    Hex = list_to_binary(integer_to_list(Byte, 16)),
    {parsing_error, <<"unexpected byte 0x", Hex/binary>>, none}.

map_json_value(Value) ->
    case Value of
        null ->
            node_nil;

        Bool when is_boolean(Bool) ->
            {node_bool, Bool};

        Int when is_integer(Int) ->
            {node_int, Int};

        Float when is_float(Float) ->
            {node_float, Float};

        String when is_binary(String) ->
            {node_str, String};

        List when is_list(List) ->
            {node_seq, lists:map(fun map_json_value/1, List)};

        {object, Pairs} ->
            {node_map, [{{node_str, Key}, map_json_value(Item)} || {Key, Item} <- Pairs]}
    end.
-endif.
