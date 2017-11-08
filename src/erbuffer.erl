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

%%  #{buff_time_inteval => 10000,
%%    buff_max_count_msg => 1000,
%%    buff_handler => handler_mod_name }  = BuffArgs
%%

start_link(Name, BuffArgs) ->
    gen_server:start_link( {local, Name}, ?MODULE, BuffArgs, []).


write_to_buffer(Name, Params) ->
    gen_server:cast(Name, {write_to_buffer, Params}).



init(#{buff_time_inteval := BuffTime} = BuffArgs) ->
    CurEts = ets:new(buffer, [ordered_set, public,  {read_concurrency, true}]),
    {ok,
        BuffArgs#{
            curr_ets => CurEts,
            curr_buff_count => 0,
            curr_timer => erlang:start_timer(BuffTime, self(), end_of_time)}}.


handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(
    {write_to_buffer, Params},
    #{
        curr_ets := CurrEts,
        buff_max_count_msg := BuffMaxCount,
        buff_count := CurrBuffCount,
        buff_handler := BuffHandler,
        curr_timer := CurrTimer,
        buff_time_inteval := BuffTime
    } = State) ->
    NewState =
        case  CurrBuffCount < BuffMaxCount of
            true ->
                ok = BuffHandler:send_to_buffer(CurrEts, Params),
                State#{curr_buff_count => CurrBuffCount + 1};
            false ->
                erlang:cancel_timer(CurrTimer),
                ok = BuffHandler:write_buffer_to(CurrEts, Params),
                NewEts = ets:new(buffer, [ordered_set, public,  {read_concurrency, true}]),
                State#{
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
        curr_ets := CurrEts,
        buff_handler := BuffHandler,
        buff_time_inteval := BuffTime
    } = State) ->
    ok = BuffHandler:write_buffer_to(CurrEts, #{}),
    NewEts = ets:new(buffer, [ordered_set, public,  {read_concurrency, true}]),
    {noreply, State#{
        curr_buff_count => 0,
        curr_ets => NewEts,
        curr_timer => erlang:start_timer(BuffTime, self(), end_of_time)}};

handle_info(_Info, State) ->
    {noreply, State}.


terminate(_Reason,
    #{
        curr_ets := CurrEts,
        buff_handler := BuffHandler,
        curr_timer := CurrTimer
    } = _State) ->
    erlang:cancel_timer(CurrTimer),
    ok = BuffHandler:write_buffer_to(CurrEts, #{}),
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


