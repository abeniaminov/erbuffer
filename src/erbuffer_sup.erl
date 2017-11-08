%%%-------------------------------------------------------------------
%%% @author abeniaminov
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. Нояб. 2017 15:54
%%%-------------------------------------------------------------------
-module(erbuffer_sup).
-author("abeniaminov").

-behaviour(supervisor).

%% API
-export([start_link/0, start_buffer/2]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%% Helper macro for declaring children of supervisor
-define(CHILD(Name,  Arg), {Name, {erbuffer, start_link, [Name, Arg]}, temporary, 5000, worker, [erbuffer]}).

start_buffer(Name,  Arg) ->
    supervisor:start_child(?MODULE, ?CHILD(Name,  Arg)).


start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).


init([]) ->

    RestartStrategy = one_for_one,
    MaxR = 0,
    MaxT = 3600,
    {ok, {{RestartStrategy, MaxR, MaxT}, []}}.