interface WorkerBuilder[Input: Any #send, Output: Any #send]
  """
  A `WorkerBuilder` is factory for creating instances of `Worker`.
  """
  fun ref apply(): Worker[Input, Output] iso^
    """
    Called when another worker is needed.
    """
