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

%%%===================================================================
%%% API
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the server
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link(Parent) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], [Parent]).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Initializes the server
%%
%% @spec init(Args) -> {ok, State} |
%%                     {ok, State, Timeout} |
%%                     ignore |
%%                     {stop, Reason}
%% @end
%%--------------------------------------------------------------------
init([Parent]) ->
    timer:send_after(?TIMER_TICK, tick),
    {ok, #state{time = 0, parent = Parent, queue = gb_trees:empty()}}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling call messages
%%
%% @spec handle_call(Request, From, State) ->
%%                                   {reply, Reply, State} |
%%                                   {reply, Reply, State, Timeout} |
%%                                   {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, Reply, State} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling cast messages
%%
%% @spec handle_cast(Msg, State) -> {noreply, State} |
%%                                  {noreply, State, Timeout} |
%%                                  {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_cast({cast, Msg}, State = #state{time = Time}) ->
    some_caster:broadcast({syn, Msg, Time}),
    {noreply, State};
handle_cast({syn, Msg, Time}, State = #state{queue = Queue}) ->
    NewQueue = gb_trees:insert(Time, {Msg, gb_sets:from_list(some_caster:all_nodes())}, Queue),
    some_caster:broadcast({acc, self()}),
    {noreply, State#state{queue = NewQueue}};
handle_cast({acc, Time, From}, State = #state{queue = Queue, parent = Parent}) ->
    {Msg, NotAcc} = gb_trees:lookup(Time, Queue),
    StillNotAcc = gb_sets:delete(From, NotAcc),
    NewQueue = case gb_sets:is_empty(StillNotAcc) of
        true  -> 
            {OldestMsg, _} = gb_trees:smallest(Queue),
                if OldestMsg == Time ->
                        Parent ! Msg,
                        gb_sets:delete(Time);
                    true -> ok
                end;
        false -> 
            gb_trees:update(Time, {Msg, StillNotAcc}, Queue)
    end,
    {noreply, State#state{queue = NewQueue}};
handle_cast(_Msg, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Handling all non call/cast messages
%%
%% @spec handle_info(Info, State) -> {noreply, State} |
%%                                   {noreply, State, Timeout} |
%%                                   {stop, Reason, State}
%% @end
%%--------------------------------------------------------------------
handle_info(tick, State = #state{time = T}) ->
    {noreply, State#state{time = T + 1}};
handle_info(_Info, State) ->
    {noreply, State}.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any
%% necessary cleaning up. When it returns, the gen_server terminates
%% with Reason. The return value is ignored.
%%
%% @spec terminate(Reason, State) -> void()
%% @end
%%--------------------------------------------------------------------
terminate(_Reason, _State) ->
    ok.

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Convert process state when code is changed
%%
%% @spec code_change(OldVsn, State, Extra) -> {ok, NewState}
%% @end
%%--------------------------------------------------------------------
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%%===================================================================
%%% Internal functions
%%%===================================================================
