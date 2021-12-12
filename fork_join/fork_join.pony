use "collections"
use @ponyint_sched_cores[I32]()
use @printf[I32](fmt: Pointer[U8] tag, ...)

actor Coordinator[Input: Any #send, Output: Any #send]
  let _worker_builder: WorkerBuilder[Input, Output]
  let _generator: Generator[Input]
  let _accumulator: AccumulatorRunner[Input, Output]
  let _workers: SetIs[WorkerRunner[Input, Output]] = _workers.create()
  let _max_workers: USize

  new create(worker_builder: WorkerBuilder[Input, Output] iso,
    generator: Generator[Input] iso,
    accumulator: Accumulator[Output] iso,
    max_workers: USize = 0)
  =>
    _worker_builder = consume worker_builder
    _generator = consume generator
    _accumulator = AccumulatorRunner[Input, Output](consume accumulator, this)

    _max_workers = if max_workers > 0 then
      max_workers
    else
      @ponyint_sched_cores().usize()
    end

    var mw = _max_workers
    while true do
      // create worker
      let w = WorkerRunner[Input, Output](this, _accumulator, _worker_builder())
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
        let batch = _generator(_max_workers)?
        worker._receive(consume batch)
      else
        // there's no additional work to do
        _workers.unset(worker)
        // TODO: maybe this should be somewhere else
        if _workers.size() == 0 then
          _accumulator._finish()
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

  be _finished(worker: WorkerRunner[Input, Output]) =>
    """
    A worker ended early as requested by coordinator. Remove it from list.
    """
    _workers.unset(worker)
    // TODO: maybe this should be somewhere else
    if _workers.size() == 0 then
      _accumulator._finish()
    end

// TODO: Doesn't need to be public
actor AccumulatorRunner[Input: Any #send, Output: Any #send]
  let _coordinator: Coordinator[Input, Output]
  let _accumulator: Accumulator[Output]

  new create(accumulator: Accumulator[Output] iso,
    coordinator: Coordinator[Input, Output])
  =>
    _accumulator = consume accumulator
    _coordinator = coordinator

  be _receive(result: Output) =>
    _accumulator.collect(consume result)

  be _finish() =>
    _accumulator.finished()

  fun ref finish() =>
    _coordinator._terminate()

interface WorkerBuilder[Input: Any #send, Output: Any #send]
  fun ref apply(): WorkerNotify[Input, Output] iso^
    """
    Creates a new worker
    """

interface Generator[A: Any #send]
  fun ref apply(workers: USize): A^ ?
    """
    Called each time a worker needs data.

    In case it is needed to evently distribute work, the total number of workers processing data is provided in `workers`.

    If not additional data is available, `error` should be called.
    """

interface Accumulator[A: Any #send]
  fun ref collect(result: A)
    """
    Called when a worker has finished working and has a result to be
    "accumulated"
    """

  fun ref finished()
    """
    Called when all workers have reported in their results
    """

actor WorkerRunner[Input: Any #send, Output: Any #send]
  let _coordinator: Coordinator[Input, Output]
  let _accumulator: AccumulatorRunner[Input, Output]
  let _notify: WorkerNotify[Input, Output]
  var _running: Bool = false
  var _early_termination_requested: Bool = false

  new create(coordinator: Coordinator[Input, Output],
    accumulator: AccumulatorRunner[Input, Output],
    notify: WorkerNotify[Input, Output] iso)
  =>
    _coordinator = coordinator
    _accumulator = accumulator
    _notify = consume notify

  be _receive(batch: Input) =>
    if not _early_termination_requested then
      _notify.receive(consume batch)
      _notify.process(this)
    end

  be _run_again() =>
    if not _early_termination_requested then
      _notify.process(this)
    end

  be _terminate() =>
    _early_termination_requested = true
    _coordinator._finished(this)

  fun ref deliver(result: Output) =>
    """
    Called to stop processing and return a result
    """
    _accumulator._receive(consume result)
    _coordinator._request(this)

  fun ref yield() =>
    """
    Called to have the worker yield the CPU and continue later.
    """
    _run_again()

interface WorkerNotify[Input: Any #send, Output: Any #send]

  // allow accumulator to end work early

  fun ref receive(work_set: Input)
    """
    Called when new data arrives that will need to be worked on.
    """

  // when coordinator is told a worker is done
  // if all are done, then send notice to accumulator that no more work is
  //   coming
  fun ref process(worker: WorkerRunner[Input, Output] ref)
    """
    Called to get the Worker to do work. Long running workers can give control
    of the CPU back by calling `yield` on `worker`. `work` will then be called
    again at some point in the future to continue working.

    When the worker has a final value to send back to the coordinator, it should
    call `done` on the `worker`.
    """
