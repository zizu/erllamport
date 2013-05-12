-module(test).
-export([test/0]).

test() ->
    pg2:create(lamport_pg),
    Pid1 = spawn(fun() -> tester(10, 20) end),
    Pid2 = spawn(fun() -> tester(20, 30) end),
    Pid3 = spawn(fun() -> tester(30, 40) end),
    {Pid1, Pid2, Pid3}.

tester(Min, Max) ->
    {ok, Pid} = lamport:start_link([self(), lamport_pg]),
    timer:sleep(round(random:uniform() * 1000)),
    send(Min, Max, Pid),
    loop().

send(N, Max, Pid) when N < Max ->
    timer:sleep(round(random:uniform() * 100)),
    gen_server:cast(Pid, {cast, N}),
    send(N + 1, Max, Pid);
send(_, _, _) ->
    ok.


loop() -> 
    loop([]).
loop(S) -> 
    receive 
        state -> erlang:display(S), loop(S);
        A -> loop([A | S])
    end. 
