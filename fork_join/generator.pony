interface Generator[A: Any #send]
  fun ref init(workers: USize)
    """
    Called before the first time the generator is called. Allows the generator
    to distribute work based on the number of workers available.
    """

  fun ref apply(): A^ ?
    """
    Called each time a worker needs data.

    If not additional data is available, `error` should be called.
    """
