use "collections"
use "runtime_info"

actor _Coordinator[Input: Any #send, Output: Any #send]
  var _status: _CoordinatorStatus = _NotYetStarted
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _collector_runner: CollectorRunner[Input, Output]
  embed _workers: SetIs[WorkerRunner[Input, Output]] = _workers.create()
  let _max_workers: USize

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    collector: Collector[Input, Output] iso,
    auth: SchedulerInfoAuth,
    max_workers: USize = 0)
  =>
    _worker_builder = consume worker_builder
    _generator = consume generator
    _collector_runner = CollectorRunner[Input, Output](consume collector, this)

    _max_workers = if max_workers > 0 then
      max_workers
    else
      Scheduler.schedulers(auth).usize()
    end

    _generator.init(_max_workers)

  be _request(worker: WorkerRunner[Input, Output]) =>
    """
    Request additional work be generated and delivered to `worker`.
    """
    if _workers.contains(worker) then
      try
        let batch = _generator()?
        worker._receive(consume batch)
      else
        _worker_finished(worker)
      end
    else
      _Fail()
    end

  be _start() =>
    if _status is _NotYetStarted then
      _status = _Started

      var mw = _max_workers
      while true do
        // create worker
        let w = WorkerRunner[Input, Output](this,
          _collector_runner,
          _worker_builder())
        _workers.set(w)

        // request data for the worker
        _request(w)

        // Run down max workers
        mw = mw - 1
        if mw == 0 then break end
      end
    end

  be _terminate() =>
    """
    Sends a message to every worker to stop processing. The job will eventually
    end but it won't be immediately as each work needs to receive and act on
    the message telling it to terminate.

    Long-running workers that don't periodically yield could run for a very long
    time making termination an extended proposition.
    """
    if _status is _Started then
      _status = _Terminating

      for worker in _workers.values() do
        worker._terminate()
      end
    end

  be _worker_finished(worker: WorkerRunner[Input, Output]) =>
    """
    Is done, either because it requested more work and the generator is out or
    because, it was asked to terminate early and it has complied.
    """
    _workers.unset(worker)
    if _workers.size() == 0 then
      _collector_runner._finish()
    end

type _CoordinatorStatus is (_NotYetStarted | _Started | _Terminating)
