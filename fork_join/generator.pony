interface Generator[A: Any #send]
  """
  A `Generator` creates data on demand which will be sent to various
  [`Worker`](/fork_join/fork_join-Worker/) instances where the data will be processed.
  """
  fun ref init(workers: USize)
    """
    Called before the first time the generator is called. Allows the generator
    to distribute work based on the number of workers available.
    """

  fun ref apply(): A^ ?
    """
    Called each time a worker needs data.

    If no additional data is available, `error` should be returned.
    """
