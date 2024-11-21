sidebarNodes={"extras":[{"group":"","headers":[{"anchor":"modules","id":"Modules"}],"id":"api-reference","title":"API Reference"},{"group":"","headers":[{"anchor":"augment-ecto-schema","id":"Augment Ecto schema"},{"anchor":"terminology","id":"Terminology"},{"anchor":"api-overview","id":"API overview"},{"anchor":"conditions","id":"Conditions"},{"anchor":"rule-results","id":"Rule results"},{"anchor":"references","id":"References"},{"anchor":"arguments","id":"Arguments"},{"anchor":"overriding-existing-fields","id":"Overriding existing fields"},{"anchor":"binding-subject-parts","id":"Binding subject parts"},{"anchor":"local-aliases","id":"Local aliases"},{"anchor":"calling-functions","id":"Calling functions"},{"anchor":"querying","id":"Querying"},{"anchor":"transforming-lists","id":"Transforming lists"},{"anchor":"counting","id":"Counting"}],"id":"full_reference","title":"Full Reference"},{"group":"","headers":[],"id":"welcome","title":"Welcome 👋"},{"group":"Basics","headers":[],"id":"00_intro","title":"Introduction"},{"group":"Basics","headers":[],"id":"01_predicates","title":"Predicates"},{"group":"Basics","headers":[],"id":"02_associations","title":"Associations"},{"group":"Basics","headers":[],"id":"03_conditions","title":"Conditions"},{"group":"Basics","headers":[],"id":"04_references","title":"References"},{"group":"Basics","headers":[],"id":"05_arguments","title":"Arguments"},{"group":"Basics","headers":[],"id":"06_thinking_in_dx","title":"Thinking in Dx"},{"group":"Basics","headers":[],"id":"99_outro","title":"Done 🎉"}],"modules":[{"deprecated":false,"group":"","id":"Dx","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"filter/3","deprecated":false,"id":"filter/3","title":"filter(records, condition, opts \\\\ [])"},{"anchor":"get/3","deprecated":false,"id":"get/3","title":"get(records, predicates, opts \\\\ [])"},{"anchor":"get!/3","deprecated":false,"id":"get!/3","title":"get!(records, predicates, opts \\\\ [])"},{"anchor":"load/3","deprecated":false,"id":"load/3","title":"load(records, predicates, opts \\\\ [])"},{"anchor":"load!/3","deprecated":false,"id":"load!/3","title":"load!(records, predicates, opts \\\\ [])"},{"anchor":"put/3","deprecated":false,"id":"put/3","title":"put(records, predicates, opts \\\\ [])"},{"anchor":"put!/3","deprecated":false,"id":"put!/3","title":"put!(records, predicates, opts \\\\ [])"},{"anchor":"query_all/3","deprecated":false,"id":"query_all/3","title":"query_all(queryable, condition, opts \\\\ [])"},{"anchor":"query_one/3","deprecated":false,"id":"query_one/3","title":"query_one(queryable, condition, opts \\\\ [])"},{"anchor":"reject/3","deprecated":false,"id":"reject/3","title":"reject(records, condition, opts \\\\ [])"}]}],"sections":[],"title":"Dx"},{"deprecated":false,"group":"","id":"Dx.Defd","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"defd/2","deprecated":false,"id":"defd/2","title":"defd(call, list)"},{"anchor":"defdp/2","deprecated":false,"id":"defdp/2","title":"defdp(call, list)"},{"anchor":"get/2","deprecated":false,"id":"get/2","title":"get(call, opts \\\\ [])"},{"anchor":"get!/2","deprecated":false,"id":"get!/2","title":"get!(call, opts \\\\ [])"},{"anchor":"load/2","deprecated":false,"id":"load/2","title":"load(call, opts \\\\ [])"},{"anchor":"load!/2","deprecated":false,"id":"load!/2","title":"load!(call, opts \\\\ [])"},{"anchor":"non_dx/1","deprecated":false,"id":"non_dx/1","title":"non_dx(code)"}]}],"sections":[{"anchor":"module-background","id":"Background"},{"anchor":"module-how-it-works","id":"How it works"},{"anchor":"module-caveats","id":"Caveats"},{"anchor":"module-currently-supported","id":"Currently supported"}],"title":"Dx.Defd"},{"deprecated":false,"group":"","id":"Dx.Ecto.Query.Batches","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"add_filters/3","deprecated":false,"id":"add_filters/3","title":"add_filters(state \\\\ %{}, group, filters)"},{"anchor":"get_batches/1","deprecated":false,"id":"get_batches/1","title":"get_batches(state)"},{"anchor":"map_put_in/3","deprecated":false,"id":"map_put_in/3","title":"map_put_in(map, list, value)"},{"anchor":"new/0","deprecated":false,"id":"new/0","title":"new()"}]}],"sections":[{"anchor":"module-problem","id":"Problem"},{"anchor":"module-approach","id":"Approach"},{"anchor":"module-examples","id":"Examples"}],"title":"Dx.Ecto.Query.Batches"},{"deprecated":false,"group":"","id":"Dx.Ecto.Schema","sections":[],"title":"Dx.Ecto.Schema"},{"deprecated":false,"group":"","id":"Dx.Result","nodeGroups":[{"key":"types","name":"Types","nodes":[{"anchor":"t:b/0","deprecated":false,"id":"b/0","title":"b()"},{"anchor":"t:binds/0","deprecated":false,"id":"binds/0","title":"binds()"},{"anchor":"t:v/0","deprecated":false,"id":"v/0","title":"v()"}]},{"key":"functions","name":"Functions","nodes":[{"anchor":"all?/2","deprecated":false,"id":"all?/2","title":"all?(enum, mapper \\\\ &identity/1)"},{"anchor":"any?/2","deprecated":false,"id":"any?/2","title":"any?(enum, mapper \\\\ &identity/1)"},{"anchor":"bind/3","deprecated":false,"id":"bind/3","title":"bind(other, key, val)"},{"anchor":"count/2","deprecated":false,"id":"count/2","title":"count(enum, fun \\\\ &identity/1)"},{"anchor":"count_while/2","deprecated":false,"id":"count_while/2","title":"count_while(enum, fun \\\\ &identity/1)"},{"anchor":"filter_map/3","deprecated":false,"id":"filter_map/3","title":"filter_map(enum, fun \\\\ &identity/1, result_mapper \\\\ &ok/2)"},{"anchor":"find/4","deprecated":false,"id":"find/4","title":"find(enum, fun \\\\ &identity/1, result_mapper \\\\ &ok/2, default \\\\ ok(nil))"},{"anchor":"from_simple/1","deprecated":false,"id":"from_simple/1","title":"from_simple(other)"},{"anchor":"map/2","deprecated":false,"id":"map/2","title":"map(enum, mapper \\\\ &identity/1)"},{"anchor":"map_keyword_values/2","deprecated":false,"id":"map_keyword_values/2","title":"map_keyword_values(enum, mapper \\\\ &identity/1)"},{"anchor":"map_values/2","deprecated":false,"id":"map_values/2","title":"map_values(enum, mapper \\\\ &identity/1)"},{"anchor":"ok/2","deprecated":false,"id":"ok/2","title":"ok(value, binds \\\\ %{})"},{"anchor":"then/2","deprecated":false,"id":"then/2","title":"then(other, fun)"},{"anchor":"to_simple/1","deprecated":false,"id":"to_simple/1","title":"to_simple(other)"},{"anchor":"to_simple_if/2","deprecated":false,"id":"to_simple_if/2","title":"to_simple_if(other, arg2)"},{"anchor":"transform/2","deprecated":false,"id":"transform/2","title":"transform(other, fun)"},{"anchor":"unwrap!/1","deprecated":false,"id":"unwrap!/1","title":"unwrap!(arg)"},{"anchor":"wrap/1","deprecated":false,"id":"wrap/1","title":"wrap(term)"}]}],"sections":[{"anchor":"module-data-loading","id":"Data loading"}],"title":"Dx.Result"},{"deprecated":false,"group":"Extending","id":"Dx.Defd.Ext","nodeGroups":[{"key":"callbacks","name":"Callbacks","nodes":[{"anchor":"c:__fun_info/2","deprecated":false,"id":"__fun_info/2","title":"__fun_info(atom, non_neg_integer)"}]},{"key":"functions","name":"Functions","nodes":[{"anchor":"defd_/1","deprecated":false,"id":"defd_/1","title":"defd_(call)"},{"anchor":"defd_/2","deprecated":false,"id":"defd_/2","title":"defd_(call, list)"},{"anchor":"defscope/1","deprecated":false,"id":"defscope/1","title":"defscope(call)"},{"anchor":"defscope/2","deprecated":false,"id":"defscope/2","title":"defscope(call, list)"}]}],"sections":[{"anchor":"module-usage","id":"Usage"},{"anchor":"module-options","id":"Options"}],"title":"Dx.Defd.Ext"},{"deprecated":false,"group":"Extending","id":"Dx.Defd.Fn","nodeGroups":[{"key":"types","name":"Types","nodes":[{"anchor":"t:t/0","deprecated":false,"id":"t/0","title":"t()"}]},{"key":"functions","name":"Functions","nodes":[{"anchor":"maybe_unwrap/1","deprecated":false,"id":"maybe_unwrap/1","title":"maybe_unwrap(other)"},{"anchor":"maybe_unwrap_final_args_ok/1","deprecated":false,"id":"maybe_unwrap_final_args_ok/1","title":"maybe_unwrap_final_args_ok(other)"},{"anchor":"maybe_unwrap_ok/1","deprecated":false,"id":"maybe_unwrap_ok/1","title":"maybe_unwrap_ok(other)"},{"anchor":"to_defd_fun/1","deprecated":false,"id":"to_defd_fun/1","title":"to_defd_fun(fun)"}]}],"sections":[],"title":"Dx.Defd.Fn"},{"deprecated":false,"group":"Extending","id":"Dx.Defd.Result","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"all?/2","deprecated":false,"id":"all?/2","title":"all?(enum, mapper \\\\ &identity/1)"},{"anchor":"any?/2","deprecated":false,"id":"any?/2","title":"any?(enum, mapper \\\\ &identity/1)"},{"anchor":"collect/1","deprecated":false,"id":"collect/1","title":"collect(results)"},{"anchor":"collect_map_pairs/1","deprecated":false,"id":"collect_map_pairs/1","title":"collect_map_pairs(flat_pairs)"},{"anchor":"collect_ok/1","deprecated":false,"id":"collect_ok/1","title":"collect_ok(results)"},{"anchor":"collect_ok_reverse/2","deprecated":false,"id":"collect_ok_reverse/2","title":"collect_ok_reverse(list, acc)"},{"anchor":"collect_reverse/2","deprecated":false,"id":"collect_reverse/2","title":"collect_reverse(list, acc \\\\ {:ok, []})"},{"anchor":"combine/2","deprecated":false,"id":"combine/2","title":"combine(elem, acc)"},{"anchor":"filter/3","deprecated":false,"id":"filter/3","title":"filter(enum, fun, eval)"},{"anchor":"find/4","deprecated":false,"id":"find/4","title":"find(enum, fun \\\\ &identity/1, result_mapper \\\\ &ok/1, default \\\\ ok(nil))"},{"anchor":"find_value/3","deprecated":false,"id":"find_value/3","title":"find_value(enum, fun, default \\\\ ok(nil))"},{"anchor":"map/2","deprecated":false,"id":"map/2","title":"map(enum, mapper \\\\ &identity/1)"},{"anchor":"map/3","deprecated":false,"id":"map/3","title":"map(enum, mapper, result_mapper)"},{"anchor":"map_then_reduce/3","deprecated":false,"id":"map_then_reduce/3","title":"map_then_reduce(enum, mapper, fun)"},{"anchor":"map_then_reduce/4","deprecated":false,"id":"map_then_reduce/4","title":"map_then_reduce(enum, mapper, first_fun, fun)"},{"anchor":"map_then_reduce_ok/4","deprecated":false,"id":"map_then_reduce_ok/4","title":"map_then_reduce_ok(enum, mapper, acc, fun)"},{"anchor":"map_then_reduce_ok_while/4","deprecated":false,"id":"map_then_reduce_ok_while/4","title":"map_then_reduce_ok_while(enum, mapper, acc, fun)"},{"anchor":"merge/2","deprecated":false,"id":"merge/2","title":"merge(arg1, arg2)"},{"anchor":"ok/1","deprecated":false,"id":"ok/1","title":"ok(value)"},{"anchor":"reduce/2","deprecated":false,"id":"reduce/2","title":"reduce(enum, fun)"},{"anchor":"reduce/3","deprecated":false,"id":"reduce/3","title":"reduce(enum, acc, fun)"},{"anchor":"reduce_while/3","deprecated":false,"id":"reduce_while/3","title":"reduce_while(enum, acc, fun)"},{"anchor":"reject/3","deprecated":false,"id":"reject/3","title":"reject(enum, fun, eval)"},{"anchor":"then/2","deprecated":false,"id":"then/2","title":"then(other, fun)"},{"anchor":"transform/1","deprecated":false,"id":"transform/1","title":"transform(other)"},{"anchor":"transform/2","deprecated":false,"id":"transform/2","title":"transform(other, empty_fallback)"},{"anchor":"transform/3","deprecated":false,"id":"transform/3","title":"transform(other, empty_fallback, fun)"},{"anchor":"transform_while/2","deprecated":false,"id":"transform_while/2","title":"transform_while(other, fun)"}]}],"sections":[{"anchor":"module-data-loading","id":"Data loading"}],"title":"Dx.Defd.Result"},{"deprecated":false,"group":"Extending","id":"Dx.Evaluation","nodeGroups":[{"key":"types","name":"Types","nodes":[{"anchor":"t:t/0","deprecated":false,"id":"t/0","title":"t()"}]},{"key":"functions","name":"Functions","nodes":[{"anchor":"add_options/2","deprecated":false,"id":"add_options/2","title":"add_options(eval, opts)"},{"anchor":"from_options/1","deprecated":false,"id":"from_options/1","title":"from_options(opts)"}]}],"sections":[],"title":"Dx.Evaluation"},{"deprecated":false,"group":"Extending","id":"Dx.Scope","nodeGroups":[{"key":"types","name":"Types","nodes":[{"anchor":"t:t/0","deprecated":false,"id":"t/0","title":"t()"}]},{"key":"functions","name":"Functions","nodes":[{"anchor":"add_conditions/2","deprecated":false,"id":"add_conditions/2","title":"add_conditions(scope, ext_ok_fun)"},{"anchor":"all/1","deprecated":false,"id":"all/1","title":"all(module)"},{"anchor":"lookup/2","deprecated":false,"id":"lookup/2","title":"lookup(scope, eval)"},{"anchor":"map_plan/2","deprecated":false,"id":"map_plan/2","title":"map_plan(scope, fun)"},{"anchor":"maybe_atom/1","deprecated":false,"id":"maybe_atom/1","title":"maybe_atom(atom)"},{"anchor":"maybe_load/2","deprecated":false,"id":"maybe_load/2","title":"maybe_load(other, eval)"},{"anchor":"maybe_lookup/2","deprecated":false,"id":"maybe_lookup/2","title":"maybe_lookup(scope, eval)"}]}],"sections":[],"title":"Dx.Scope"},{"deprecated":false,"group":"Exceptions","id":"Dx.Ecto.Query.TranslationError","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"message/1","deprecated":false,"id":"message/1","title":"message(e)"}]}],"sections":[],"title":"Dx.Ecto.Query.TranslationError"},{"deprecated":false,"group":"Exceptions","id":"Dx.Error.Generic","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"message/1","deprecated":false,"id":"message/1","title":"message(error)"}]}],"sections":[],"title":"Dx.Error.Generic"},{"deprecated":false,"group":"Exceptions","id":"Dx.Error.NotLoaded","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"message/1","deprecated":false,"id":"message/1","title":"message(error)"}]}],"sections":[],"title":"Dx.Error.NotLoaded"},{"deprecated":false,"group":"Exceptions","id":"Dx.Error.RulesNotFound","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"message/1","deprecated":false,"id":"message/1","title":"message(error)"}]}],"sections":[],"title":"Dx.Error.RulesNotFound"},{"deprecated":false,"group":"Exceptions","id":"Dx.Error.Timeout","nodeGroups":[{"key":"functions","name":"Functions","nodes":[{"anchor":"message/1","deprecated":false,"id":"message/1","title":"message(error)"}]}],"sections":[],"title":"Dx.Error.Timeout"}],"tasks":[]}