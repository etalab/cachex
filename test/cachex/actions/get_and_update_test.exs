defmodule Cachex.Actions.GetAndUpdateTest do
  use CachexCase

  test "retrieving and updated cache records" do
    # create a forwarding hook
    hook = ForwardHook.create(%{ results: true })

    # create a test cache
    cache = Helper.create_cache([ hooks: [ hook ] ])

    # set some keys in the cache
    { :ok, true } = Cachex.set(cache, 1, 1)
    { :ok, true } = Cachex.set(cache, 2, 2, ttl: 1)
    { :ok, true } = Cachex.set(cache, 5, 5, ttl: 1000)

    # wait for the TTL to pass
    :timer.sleep(25)

    # flush all existing messages
    Helper.flush()

    # update the first and second keys
    result1 = Cachex.get_and_update(cache, 1, &to_string/1)
    result2 = Cachex.get_and_update(cache, 2, &to_string/1)

    # update a missing key
    result3 = Cachex.get_and_update(cache, 3, &to_string/1)

    # define the fallback options
    fb_opts = [ fallback: fn(key) ->
      "_#{key}_"
    end ]

    # update a fallback key
    result4 = Cachex.get_and_update(cache, 4, &to_string/1, fb_opts)

    # update the fifth value
    result5 = Cachex.get_and_update(cache, 5, &to_string/1)

    # verify the first key is retrieved
    assert(result1 == { :ok, "1" })

    # verify the second and third keys are missing
    assert(result2 == { :missing, "" })
    assert(result3 == { :missing, "" })

    # verify the fourth key uses the fallback
    assert(result4 == { :loaded, "_4_" })

    # verify the fifth result
    assert(result5 == { :ok, "5" })

    # assert we receive valid notifications
    assert_receive({ { :get_and_update, [ 1, _to_string, [ ] ] }, ^result1 })
    assert_receive({ { :get_and_update, [ 2, _to_string, [ ] ] }, ^result2 })
    assert_receive({ { :get_and_update, [ 3, _to_string, [ ] ] }, ^result3 })
    assert_receive({ { :get_and_update, [ 4, _to_string, ^fb_opts ] }, ^result4 })
    assert_receive({ { :get_and_update, [ 5, _to_string, [ ] ] }, ^result5 })

    # check we received valid purge actions for the TTL
    assert_receive({ { :purge, [[]] }, { :ok, 1 } })

    # retrieve all entries from the cache
    value1 = Cachex.get(cache, 1)
    value2 = Cachex.get(cache, 2)
    value3 = Cachex.get(cache, 3)
    value4 = Cachex.get(cache, 4)
    value5 = Cachex.get(cache, 5)

    # all should now have values
    assert(value1 == { :ok, "1" })
    assert(value2 == { :ok, "" })
    assert(value3 == { :ok, "" })
    assert(value4 == { :ok, "_4_" })
    assert(value5 == { :ok, "5" })

    # check the TTL on the last key
    ttl1 = Cachex.ttl!(cache, 5)

    # TTL should be maintained
    assert_in_delta(ttl1, 965, 11)
  end

end
