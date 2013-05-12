-module(lamport).

-behaviour(gen_server).

%% API
-export([start_link/1]).

%% gen_server callbacks
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {parent, time, queue}).

%% Lamport timer tick im msecs
-define(TIMER_TICK, 1000).

start_link(Parent) ->
    gen_server:start_link(?MODULE, Parent, []).

init(Parent) ->
    timer:send_interval(?TIMER_TICK, tick),
    {ok, #state{time = 0, parent = Parent, queue = gb_trees:empty()}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast({cast, Msg}, State = #state{time = Time}) ->
    NewTime = Time + 1,
    lamport_sup:broadcast({syn, Msg, NewTime, self()}),
    {noreply, State#state{time = NewTime}};
handle_cast({syn, Msg, Time, From}, State = #state{queue = Queue, time = SelfTime}) ->
    NewTime = new_time(Time, SelfTime),
    NewQueue = gb_trees:insert({Time, From}, {Msg, gb_sets:from_list(lamport_sup:all_pids())}, Queue),
    lamport_sup:broadcast({acc, {Time, From}, NewTime, self()}),
    {noreply, State#state{queue = NewQueue, time = NewTime}};
handle_cast({acc, MsgId, Time, From}, State = #state{queue = Queue, parent = Parent, time = SelfTime}) ->
    NewTime = new_time(Time, SelfTime),
    {value, {Msg, NotAcc}} = gb_trees:lookup(MsgId, Queue),
    StillNotAcc = gb_sets:delete(From, NotAcc),
    NewQueue = gb_trees:update(MsgId, {Msg, StillNotAcc}, Queue),
    {SmallestKey, {SmallestMsg, SmallestNotAcc}} = gb_trees:smallest(NewQueue),
    NewestQueue = case gb_sets:is_empty(SmallestNotAcc) of
        true  ->
            Parent ! SmallestMsg,
            gb_trees:delete(SmallestKey, NewQueue);
        false ->
            NewQueue
    end,
    {noreply, State#state{queue = NewestQueue, time = NewTime}};
handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(tick, State = #state{time = T}) ->
    {noreply, State#state{time = T + 1}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

new_time(T1, T2) ->
    max(T1, T2) + 1.
