%%%-------------------------------------------------------------------
%%% @author abeniaminov
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. Нояб. 2017 15:53
%%%-------------------------------------------------------------------
-module(erbuffer_app).
-author("abeniaminov").

-behaviour(application).

%% Application callbacks
-export([start/2,
    stop/1]).


start(_StartType, _StartArgs) ->
    case erbuffer_sup:start_link() of
        {ok, Pid} ->
            case env(buffer) of
                {ok, Buffers} ->
                    load_buffers(Buffers);
                _ ->
                    ok
            end,

            {ok, Pid};
        Error ->
            Error
    end.


stop(_State) ->
    ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================
env(Key) ->
    application:get_env(erbuffer, Key).


load_buffers(Buffers) ->
    Fun = fun({BufferName, Options}) ->  {ok, _} = add_buffer(BufferName, Options) end,
    ok = lists:foreach(Fun, Buffers).

lookup(Key, List, Default) ->
    case lists:keyfind(Key, 1, List) of
        {Key, Result} ->
            Result;
        false ->
            Default
    end.

lookup(Key, List) ->
    lookup(Key, List, null).

add_buffer(Name, Options) ->
    Args = #{
        buff_time_inteval =>  lookup(time_inteval,  Options, 10000),
        buff_max_count_msg => lookup(max_count_msg,  Options, 1000),
        buff_handler => lookup(handler,  Options)
    },
    erbuffer_sup:start_buffer(Name, Args).