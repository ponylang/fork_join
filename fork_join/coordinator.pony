use "collections"
use @ponyint_sched_cores[I32]()

actor Coordinator[Input: Any #send, Output: Any #send]
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _collector_runner: CollectorRunner[Input, Output]
  embed _workers: SetIs[WorkerRunner[Input, Output]] = _workers.create()
  let _max_workers: USize

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    collector: Collector[Input, Output] iso,
    max_workers: USize = 0)
  =>
    _worker_builder = consume worker_builder
    _generator = consume generator
    _collector_runner = CollectorRunner[Input, Output](consume collector, this)

    _max_workers = if max_workers > 0 then
      max_workers
    else
      @ponyint_sched_cores().usize()
    end

    _generator.init(_max_workers)

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

  be _request(worker: WorkerRunner[Input, Output]) =>
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

  be _terminate() =>
    // send message to each worker to stop working
    for worker in _workers.values() do
      worker._terminate()
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
