-module(lamport).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-record(state, {parent, time, queue, pg}).

%% Lamport timer tick im msecs
-define(TIMER_TICK, 1000).

start_link([Parent, Pg]) ->
    gen_server:start_link(?MODULE, [Parent, Pg], []).

init([Parent, Pg]) ->
    pg2:join(Pg, self()),
    timer:send_interval(?TIMER_TICK, tick),
    {ok, #state{time = 0, parent = Parent, queue = gb_trees:empty(), pg = Pg}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast({cast, Msg}, State = #state{time = Time, pg = Pg}) ->
    NewTime = Time + 1,
    broadcast({syn, Msg, NewTime, self()}, Pg),
    {noreply, State#state{time = NewTime}};

handle_cast({syn, Msg, Time, From}, State = #state{queue = Queue, time = SelfTime, pg = Pg}) ->
    NewTime = new_time(Time, SelfTime),
    NewQueue = gb_trees:insert({Time, From}, {Msg, gb_sets:from_list(pg2:get_members(Pg))}, Queue),
    broadcast({acc, {Time, From}, NewTime, self()}, Pg),
    {noreply, State#state{queue = NewQueue, time = NewTime}};

handle_cast(Acc = {acc, MsgId, Time, From}, State = #state{queue = Queue, parent = Parent, time = SelfTime}) ->
    NewTime = new_time(Time, SelfTime),
    case gb_trees:lookup(MsgId, Queue) of
        {value, {Msg, NotAcc}} ->
            StillNotAcc = gb_sets:delete(From, NotAcc),
            UpdatedQueue = gb_trees:update(MsgId, {Msg, StillNotAcc}, Queue),
            NewQueue = send_acked(UpdatedQueue, Parent),
            {noreply, State#state{queue = NewQueue, time = NewTime}};
        none -> % acc before syn
            gen_server:cast(self(), Acc),
            {noreply, State}
    end;

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

broadcast(Msg, Pg) ->
    [gen_server:cast(Pid, Msg) || Pid <- pg2:get_members(Pg)].

send_acked(Queue, Parent) ->
    {SmallestKey, {SmallestMsg, SmallestNotAcc}} = gb_trees:smallest(Queue),
    case gb_sets:is_empty(SmallestNotAcc) of
        true  ->
            Parent ! SmallestMsg,
            NewQueue = gb_trees:delete(SmallestKey, Queue),
            case gb_trees:is_empty(NewQueue) of
                false ->
                    send_acked(NewQueue, Parent);
                true ->
                    NewQueue
            end;
        false ->
            Queue
    end.
