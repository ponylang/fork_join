use "runtime_info"

actor Job[Input: Any #send, Output: Any #send]
  """
  `Job` sets up a new `fork_join` processing tasks and provides the user with a
  means to start the job and terminate it before the
  [`Generator`](./fork_join-Generator/) runs out of data.
  """
  var _status: _JobStatus = _NotYetStarted
  let _coordinator: _Coordinator[Input, Output]

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    collector: Collector[Input, Output] iso,
    auth: SchedulerInfoAuth,
    max_workers: USize = 0)
  =>
    _coordinator = _Coordinator[Input, Output](consume worker_builder,
      consume generator,
      consume collector,
      auth,
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
    if _status is _Started then
      _status = _Terminating
      _coordinator._terminate()
    end

type _JobStatus is (_Started | _Terminating | _NotYetStarted)
