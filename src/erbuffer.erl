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
-export([start_link/2, write_to_buffer/2, get_active/1, set_active/2]).

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

get_active(Name) ->
    gen_server:call(Name, get_active).

set_active(Name, Active) ->
    gen_server:call(Name, {set_active, Active}).


init(#{buff_time_interval := BuffTime, active := Active } = BuffArgs) ->
    CurEts = ets:new(buffer, [ordered_set, public,  {write_concurrency, true}]),
    put(is_active_buffer, Active),
    {ok,
        BuffArgs#{
            ets_pool => [],
            curr_ets => CurEts,
            curr_buff_count => 0,
            curr_timer =>
                case Active of
                    true -> erlang:start_timer(BuffTime, self(), end_of_time);
                    false -> none
                end
        }
    }.

handle_call(get_active, _From, State) ->
    {reply, {active,  get(is_active_buffer)}, State};

handle_call({set_active, Active}, _From,
    #{
        curr_timer := CurrTimer,
        buff_time_interval := BuffTime,
        buff_handler := BuffHandler,
        curr_ets := CurrEts
    } = State) ->
    OldActive = get(is_active_buffer),
    NewTimerRef =
        case OldActive of
            false ->
                case Active of
                    false ->
                        CurrTimer;
                    true ->
                        put(is_active_buffer, true),
                        erlang:start_timer(BuffTime, self(), end_of_time)

                end;
            true ->
                case Active of
                    true ->
                        CurrTimer;
                    false ->
                        put(is_active_buffer, false),
                        erlang:cancel_timer(CurrTimer),
                        BuffHandler:write_buffer_to(CurrEts, #{}),
                        ets:delete_all_objects(CurrEts),
                        none
                end
        end,
    {reply, ok, State#{curr_timer => NewTimerRef, curr_buff_count => 0}};

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
    case get(is_active_buffer) of
        true ->
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
        false ->  {noreply, State}
    end;

handle_cast(_Request, State) ->
    {noreply, State}.


handle_info(
    {timeout, _TimerRef, end_of_time},
    #{
        ets_pool := EtsPool,
        curr_ets := CurrEts,
        buff_handler := BuffHandler,
        buff_time_interval := BuffTime } = State) ->

    case get(is_active_buffer) of
        true ->
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
        false ->
            {noreply, State}
    end;


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
    case get(is_active_buffer) of
        true ->
            erlang:cancel_timer(CurrTimer),
            BuffHandler:write_buffer_to(CurrEts, #{});
        false -> nothing
    end,
    ok.


code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


