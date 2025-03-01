defmodule Cachex.Policy.LRW.Evented do
  @moduledoc """
  Evented least recently written eviction policy for Cachex.

  This module implements an evented LRW eviction policy for Cachex, using a hook
  to listen for new key additions to a cache and enforcing bounds in a reactive
  way. This policy enforces cache bounds and limits far more accurately than other
  scheduled implementations, but comes at a higher memory cost (due to the message
  passing between hooks).
  """
  use Cachex.Hook

  # import macros
  import Cachex.Spec

  # add internal aliases
  alias Cachex.Policy.LRW

  # actions which didn't trigger a write
  @ignored [:error, :ignored]

  ######################
  # Hook Configuration #
  ######################

  @doc """
  Returns the actions this policy should listen on.
  """
  @spec actions :: [atom]
  def actions,
    do: [
      :put,
      :decr,
      :incr,
      :fetch,
      :update,
      :put_many,
      :get_and_update
    ]

  @doc """
  Returns the provisions this policy requires.
  """
  @spec provisions :: [atom]
  def provisions,
    do: [:cache]

  ####################
  # Server Callbacks #
  ####################

  @doc false
  # Initializes this policy using the limit being enforced.
  def init(limit() = limit),
    do: {:ok, {nil, limit}}

  @doc false
  # Handles notification of a cache action.
  #
  # This will check if the action can modify the size of the cache, and if so will
  # execute the boundary enforcement to trim the size as needed.
  #
  # Note that this will ignore error results and only operates on actions which are
  # able to cause a net gain in cache size (so removals are also ignored).
  def handle_notify(_message, {status, _value}, {cache, limit} = opts)
      when status not in @ignored,
      do: LRW.apply_limit(cache, limit) && {:ok, opts}

  def handle_notify(_message, _result, opts),
    do: {:ok, opts}

  @doc false
  # Receives a provisioned cache instance.
  #
  # The provided cache is then stored in the cache and used for cache calls going
  # forwards, in order to skip the lookups inside the cache overseer for performance.
  def handle_provision({:cache, cache}, {_cache, limit}),
    do: {:ok, {cache, limit}}
end
