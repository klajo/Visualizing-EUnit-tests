-module(eunit_tracing).

-export([t/0,t/1]).

-export([test_start/0, test_end/0, test_group_start/0,
         test_group_end/0, test_negative/0, test_negative/1]).

-export([map_tuple/2, test_wrap/1, test__wrap/1,
         test__group_wrap/1, negative_wrap/1]).

%%
%% Top-level function to initiate tracing.
%%

%% Tracing function which traces calls to functions in frequency
%% as well as "skip" functions here used to punctuate the trace.

t() ->
    t(frequency).

t(Mod)
  when is_atom(Mod) ->
    code:load_file(Mod),
    code:load_file(addTestSuffix(Mod)),
    erlang:trace(all, true, [call]),
    erlang:trace_pattern({eunit_tracing, test_start, '_'}, true, [local]),
    erlang:trace_pattern({eunit_tracing, test_end, '_'}, true, [local]),    
    erlang:trace_pattern({eunit_tracing, test_group_start, '_'}, true, [local]),
    erlang:trace_pattern({eunit_tracing, test_group_end, '_'}, true, [local]),    
    erlang:trace_pattern({eunit_tracing, test_negative, '_'}, true, [local]),    
    erlang:trace_pattern({Mod, '_', '_'}, true, [global]).

addTestSuffix(Mod) ->
    list_to_atom(lists:concat([Mod,"_test"])).

%%
%% Functions to punctuate the trace.
%%

%% These are "skip" functions with no effect other than 
%% to be called and so to appear in the trace.

test_start() ->
    ok.

test_end() ->
    ok.

test_group_start() ->
    ok.

test_group_end() ->
    ok.

test_negative() ->
    ok.

test_negative(Test) ->
    Test.

%%
%% Wrapping up tests
%%

%% Map over a tuple (done by conversion to/from a list).

map_tuple(F,T) ->
    list_to_tuple(lists:map(F,tuple_to_list(T))).

%% Wrap a ..._test()
%% Can be positive or negative.

test_wrap(F) ->
    test_start(),
    F(),
    test_end().

%% Wrap a single component of a ..._test_()
%% Can be positive or negative.

test__wrap(F)
  when is_function(F) ->
    fun () ->
	    test_start(),
	    F(),
	    test_end()
    end;  
test__wrap(F)
  when is_tuple(F) ->
    case F of
	{setup,Setup,Teardown,Tests} ->
	    {setup,
	     % fun () ->
	     % 	     test_group_start(),
	     % 	     Setup()
	     % end,
	     Setup,
	     % fun (R) ->
	     % 	     Teardown(R),
	     % 	     test_group_end()
	     % end,
	     Teardown,
	     test__wrap(Tests)};
	_ ->    
	    map_tuple(fun test__wrap/1,F)
    end;
test__wrap(F)
  when is_list(F)->
    {setup,
     fun () -> test_group_start() end,
     fun (_) -> test_group_end() end,
     lists:map(fun test__wrap/1,F)};
test__wrap(F) ->
    F.

%% Wrap a group (list) of tests.
%% Uses a fixture to do the wrapping.

%% 2/3/11 No longer used: folded into test__wrap/1

test__group_wrap(Tests) ->
	    [{setup,
	      fun () -> test_group_start() end,
	      fun (_) -> test_group_end() end,
	      lists:map(fun test__wrap/1,Tests)}
	    ].  

%% Mark a test as negative.
%% Used in the redefinition of _assertError etc.

negative_wrap(F)
  when is_function(F) ->
    fun () ->
	    F(),
	    test_negative()
    end;  
negative_wrap(F)
  when is_tuple(F) -> 
    map_tuple(fun negative_wrap/1,F);
negative_wrap(F) ->
    F.
