interface Worker[Input: Any #send, Output: Any #send]
  """
  `Worker` instances are responsible for taking input data and an output that
  will be send to a `Collector` instance for final tabulation.
  """
  fun ref receive(work_set: Input)
    """
    Called when new data arrives that will need to be worked on. When data
    arrives via receive, it should be stored for future processing.
    """

  fun ref process(runner: WorkerRunner[Input, Output] ref)
    """
    Called to get the Worker to do work. Long running workers can give control
    of the CPU back by calling `yield` on `runner`. `process` will then be
    called again at some point in the future to start the worker back up.

    When the worker has a value to send back to the coordinator, it should
    call `deliver` on `runner`.
    """
