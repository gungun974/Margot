-module(margot_yaml_ffi).

-include_lib("yamerl/include/yamerl_errors.hrl").

-export([parse_string/1]).

parse_string(String) ->
    try
        Docs = map_yamerl_docs(yamerl_constr:string(String, [{detailed_constr, true}])),
        {ok, Docs}
    catch
        throw:#yamerl_exception{errors = [First | _]} ->
            {error, map_yamerl_error(First)};
        error:_ ->
            {error, unexpected_parsing_error}
    end.

map_yamerl_error(Error) ->
    case Error of
        #yamerl_parsing_error{text = undefined} ->
            unexpected_parsing_error;

        #yamerl_parsing_error{text = Message, line = undefined, column = undefined} ->
           {parsing_error, unicode:characters_to_binary(Message), {some, {parse_error_loc, 0, 0}}};

        #yamerl_parsing_error{text = Message, line = Line, column = Col} ->
            {parsing_error, unicode:characters_to_binary(Message), {some, {parse_error_loc, Line, Col}}};

        #yamerl_invalid_option{text = undefined} ->
            unexpected_parsing_error;

        #yamerl_invalid_option{text = Message} ->
            {parsing_error, unicode:characters_to_binary(Message), {some, {parse_error_loc, 0, 0}}}
    end.

map_yamerl_docs(Documents) ->
    lists:map(fun map_yamerl_doc/1, Documents).

map_yamerl_doc(Document) ->
    {yamerl_doc, RootNode} = Document,
    map_yamerl_node(RootNode).

map_yamerl_node(Node) ->
    case Node of
        {yamerl_null, _, _Tag, _Loc} ->
            node_nil;

        {yamerl_str, _, _Tag, _Loc, String} ->
            {node_str, unicode:characters_to_binary(String)};

        {yamerl_bool, _, _Tag, _Loc, Bool} when is_boolean(Bool) ->
            {node_bool, Bool};

        {yamerl_int, _, _Tag, _Loc, Int} when is_integer(Int) ->
            {node_int, Int};

        {yamerl_float, _, _Tag, _Loc, Float} when is_float(Float) ->
            {node_float, Float};

        {yamerl_seq, _, _Tag, _Loc, Nodes, _Count} when is_list(Nodes) ->
            {node_seq, lists:map(fun map_yamerl_node/1, Nodes)};

        {yamerl_map, _, _Tag, _Loc, Pairs} when is_list(Pairs) ->
            {node_map, map_yamerl_map(Pairs)}
    end.

map_yamerl_map(Pairs) ->
    F = fun({Key, Value}) ->
        {map_yamerl_node(Key), map_yamerl_node(Value)}
    end,
    lists:map(F, Pairs).
