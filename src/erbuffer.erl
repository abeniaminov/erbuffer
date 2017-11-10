%%%-------------------------------------------------------------------
%%% @author abeniaminov
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 07. Нояб. 2017 15:57
%%%-------------------------------------------------------------------
-module(erbuffer).
-author("abeniaminov").

-behaviour(gen_server).

%% API
-export([start_link/2,  write_to_buffer/2]).

%% gen_server callbacks
-export([init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3]).

-define(SERVER, ?MODULE).


start_link(Name, BuffArgs) ->
    gen_server:start_link( {local, Name}, ?MODULE, BuffArgs, []).


write_to_buffer(Name, Params) ->
    gen_server:cast(Name, {write_to_buffer, Params}).



init(#{buff_time_interval := BuffTime} = BuffArgs) ->
    CurEts = ets:new(buffer, [ordered_set, public,  {write_concurrency, true}]),
    {ok,
        BuffArgs#{
            ets_pool => [],
            curr_ets => CurEts,
            curr_buff_count => 0,
            curr_timer => erlang:start_timer(BuffTime, self(), end_of_time)}}.


handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(
    {write_to_buffer, Params},
    #{
        ets_pool := EtsPool,
        curr_ets := CurrEts,
        buff_max_count_msg := BuffMaxCount,
        buff_count := CurrBuffCount,
        buff_handler := BuffHandler,
        curr_timer := CurrTimer,
        buff_time_interval := BuffTime
    } = State) ->
    NewState =
        case  CurrBuffCount < BuffMaxCount of
            true ->
                spawn(
                    fun() -> BuffHandler:send_to_buffer(CurrEts, Params) end),
                State#{curr_buff_count => CurrBuffCount + 1};
            false ->
                erlang:cancel_timer(CurrTimer),
                Self = self(),
                spawn(
                    fun() ->
                        BuffHandler:write_buffer_to(CurrEts, Params),
                        ets:delete_all_objects(CurrEts),
                        Self ! {put_back, CurrEts }
                    end
                ),
                {NewEts, Pool} =
                case EtsPool of
                    [] -> {ets:new(buffer, [ordered_set, public,  {write_concurrency, true}]), []};
                    [E | Rest] ->  {E, Rest}
                end,
                State#{
                    ets_pool => Pool,
                    curr_buff_count => 0,
                    curr_ets => NewEts,
                    curr_timer => erlang:start_timer(BuffTime, self(), end_of_time)}
        end,
    {noreply, NewState};

handle_cast(_Request, State) ->
    {noreply, State}.


handle_info(
    {timeout, _TimerRef, end_of_time},
    #{
        ets_pool := EtsPool,
        curr_ets := CurrEts,
        buff_handler := BuffHandler,
        buff_time_interval := BuffTime } = State) ->

    Self = self(),
    spawn(
        fun() ->
            BuffHandler:write_buffer_to(CurrEts, #{}),
            ets:delete_all_objects(CurrEts),
            Self ! {put_back, CurrEts }
        end
    ),

    {NewEts, Pool} =
        case EtsPool of
            [] -> {ets:new(buffer, [ordered_set, public,  {write_concurrency, true}]), []};
            [E | Rest] ->  {E, Rest}
        end,
    {noreply, State#{
        ets_pool => Pool,
        curr_buff_count => 0,
        curr_ets => NewEts,
        curr_timer => erlang:start_timer(BuffTime, self(), end_of_time)}};

handle_info({put_back, UsedEts},  #{ets_pool := EtsPool} = State) ->
    {noreply, State#{ets_pool => [UsedEts | EtsPool]}};


handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason,
    #{
        curr_ets := CurrEts,
        buff_handler := BuffHandler,
        curr_timer := CurrTimer
    } = _State) ->
    erlang:cancel_timer(CurrTimer),
    BuffHandler:write_buffer_to(CurrEts, #{}),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


