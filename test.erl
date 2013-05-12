-module(test).
-export([test/0]).

test() ->
    pg2:create(lamport_pg),
    Pid1 = spawn(fun() -> tester(100, 200) end),
    Pid2 = spawn(fun() -> tester(201, 300) end),
    Pid3 = spawn(fun() -> tester(301, 400) end),
    {Pid1, Pid2, Pid3}.

tester(Min, Max) ->
    {ok, Pid} = lamport:start_link([self(), lamport_pg]),
    timer:sleep(round(random:uniform() * 1000)),
    [gen_server:cast(Pid, {cast, Num}) || Num <- lists:seq(Min, Max)],
    loop().

loop() -> 
    loop(undefined).
loop(S) -> 
    receive 
        state -> erlang:display(S), loop(S);
        A -> erlang:display({self(), A}), loop(A)
    end. 
