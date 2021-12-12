// TODO: top-level documentation
interface WorkerBuilder[Input: Any #send, Output: Any #send]
  fun ref apply(): Worker[Input, Output] iso^
    """
    Called when another worker is needed.
    """
