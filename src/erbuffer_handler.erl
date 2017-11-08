%%%-------------------------------------------------------------------
%%% @author abeniaminov
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. Нояб. 2017 16:32
%%%-------------------------------------------------------------------
-module(erbuffer_handler).
-author("abeniaminov").

%% API
-export([]).

-callback write_buffer_to(Ets, Params)
        -> ok
    when Ets::tid(), Params::#{}.

-callback send_to_buffer(Ets, Params)
        -> ok
    when Ets::tid(), Params::#{}.

