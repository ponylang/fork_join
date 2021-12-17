// TODO: top-level documentation
actor Job[Input: Any #send, Output: Any #send]
  var _status: _JobStatus = _NotYetStarted
  let _coordinator: _Coordinator[Input, Output]

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    collector: Collector[Input, Output] iso,
    max_workers: USize = 0)
  =>
    _coordinator = _Coordinator[Input, Output](consume worker_builder,
      consume generator,
      consume collector,
      max_workers)

  be start() =>
    """
    Start the job.
    """
    if _status is _NotYetStarted then
      _status = _Started
      _coordinator._start()
    end

  be terminate() =>
    """
    End the job before the generator has run out of data.
    """
    if _status is _Terminating then
      _status = _Terminating
      _coordinator._terminate()
    end

type _JobStatus is (_Started | _Terminating | _NotYetStarted)
