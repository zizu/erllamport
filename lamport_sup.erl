-module(lamport_sup).

-behaviour(supervisor).

%% API
-export([start_link/0, all_pids/0, broadcast/1]).

%% Supervisor callbacks
-export([init/1]).

-define(CHILD(Id, Mod, Type, Args), {Id, {Mod, start_link, Args},
                                     permanent, 5000, Type, [Mod]}).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @spec start_link() -> {ok, Pid} | ignore | {error, Error}
%% @end
%%--------------------------------------------------------------------
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @spec init(Args) -> {ok, {SupFlags, [ChildSpec]}} |
%%                     ignore |
%%                     {error, Reason}
%% @end
%%--------------------------------------------------------------------
init(Args) ->
    {ok, {{simple_one_for_one, 5, 10}, [?CHILD('', lamport, worker, Args)]}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

all_pids() ->
    [Pid || {_, Pid, _, _} <- supervisor:which_children(?MODULE)].

broadcast(Msg) ->
    Workers = all_pids(),
    [gen_server:cast(Pid, Msg) || Pid <- Workers].
