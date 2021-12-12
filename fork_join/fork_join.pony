use "collections"
use @ponyint_sched_cores[I32]()

actor Coordinator[Input: Any #send, Output: Any #send]
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _collector_runner: CollectorRunner[Input, Output]
  let _workers: SetIs[WorkerRunner[Input, Output]] = _workers.create()
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
        // there's no additional work to do
        _workers.unset(worker)
        // TODO: maybe this should be somewhere else
        if _workers.size() == 0 then
          _collector_runner._finish()
        end
      end
    else
      // TODO: this should never happen
      None
    end

  be _terminate() =>
    // send message to each worker to stop working
    for worker in _workers.values() do
      worker._terminate()
    end

  be _worker_finished(worker: WorkerRunner[Input, Output]) =>
    """
    A worker ended early as requested by coordinator. Remove it from list.
    """
    _workers.unset(worker)
    // TODO: maybe this should be somewhere else
    if _workers.size() == 0 then
      _collector_runner._finish()
    end

interface WorkerBuilder[Input: Any #send, Output: Any #send]
  fun ref apply(): Worker[Input, Output] iso^
    """
    Creates a new worker
    """

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
