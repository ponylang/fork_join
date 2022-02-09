interface Collector[Input: Any #send, Output: Any #send]
  """
  A `Collector` is the final step in the processing pipeline. The `Collector`
  instance receives incremental results from [`Worker`](./fork_join-Worker/)
  instances and creates a running tabulation.

  When a `fork_join` job is finished, a `finish` message will be sent to the
  collector so it can take whatever steps are required to communicate the final
  collected results.
  """
  fun ref collect(
    runner: CollectorRunner[Input, Output] ref,
    result: Output)
    """
    Called when results are received from a worker.

    If you need to end processing early, you can call `terminate` on
    `runner`. Otherwise, the job will continue.
    """

  fun ref finish()
    """
    Called when all workers have reported in their results.
    """
