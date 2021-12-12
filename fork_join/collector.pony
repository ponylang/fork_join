// TODO: top-level documentation
interface Collector[Input: Any #send, Output: Any #send]
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
